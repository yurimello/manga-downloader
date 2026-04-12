class ImageDownloaderService
  def initialize(adapter:, http_client: nil, image_delay: 0.5)
    @adapter = adapter
    @http = http_client || HttpClientService.new
    @image_delay = image_delay
  end

  def download_chapter(chapter_id, dest_dir)
    images = @adapter.fetch_chapter_images(chapter_id)
    return 0 unless images[:base_url] && images[:hash]

    FileUtils.mkdir_p(dest_dir)
    count = 0

    images[:filenames].each_with_index do |filename, idx|
      ext = File.extname(filename)
      out_path = File.join(dest_dir, format("%03d%s", idx + 1, ext))
      url = @adapter.image_url(images[:base_url], images[:hash], filename)

      if @http.download_file(url, out_path)
        count += 1
      end
    end

    count
  end
end
