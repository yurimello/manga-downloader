class ImageDownloaderService
  def initialize(adapter:, concurrency: 4, file_manager: FileManager.new)
    @adapter = adapter
    @concurrency = concurrency
    @fs = file_manager
    @downloaded_urls = Set.new
    @mutex = Mutex.new
    @cdn_conn = Faraday.new do |f|
      f.adapter Faraday.default_adapter
    end
  end

  def count_images(chapter_id)
    images = @adapter.fetch_chapter_images(chapter_id)
    return 0 unless images[:base_url] && images[:hash]
    images[:filenames].size
  end

  def download_chapter(chapter_id, dest_dir, &on_image_downloaded)
    images = @adapter.fetch_chapter_images(chapter_id)
    return 0 unless images[:base_url] && images[:hash]

    @fs.mkdir_p(dest_dir)

    tasks = images[:filenames].each_with_index.filter_map do |filename, idx|
      url = @adapter.image_url(images[:base_url], images[:hash], filename)

      skip = @mutex.synchronize { !@downloaded_urls.add?(url) }
      next if skip

      ext = @fs.extname(filename)
      out_path = @fs.join(dest_dir, format("%03d%s", idx + 1, ext))
      { url: url, out_path: out_path }
    end

    count = 0
    queue = Queue.new
    tasks.each { |t| queue << t }
    @concurrency.times { queue << :done }

    threads = @concurrency.times.map do
      Thread.new do
        while (task = queue.pop) != :done
          if cdn_download(task[:url], task[:out_path])
            @mutex.synchronize do
              count += 1
              on_image_downloaded&.call
            end
          end
        end
      end
    end

    threads.each(&:join)
    count
  end

  private

  def cdn_download(url, dest_path)
    response = @cdn_conn.get(url)
    @fs.binwrite(dest_path, response.body) if response.status == 200
    response.status == 200
  rescue Faraday::Error
    false
  end
end
