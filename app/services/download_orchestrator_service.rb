class DownloadOrchestratorService
  def initialize(download)
    @download = download
    @adapter = AdapterRegistry.for_url(download.url)
    @languages = load_languages
  end

  def call
    @download.update!(status: :downloading, started_at: Time.current)
    broadcast_status

    manga_id = @adapter.extract_manga_id(@download.url)
    log!("Extracted manga ID: #{manga_id}")

    title = @adapter.fetch_manga_title(manga_id)
    @download.update!(title: title, manga_id: manga_id)
    log!("Title: #{title}")
    broadcast_status

    log!("Fetching chapters...")
    raw_chapters = @adapter.fetch_chapters(manga_id, languages: @languages)
    log!("Found #{raw_chapters.size} total chapters across all languages")

    volumes_filter = parse_volumes(@download.volumes)
    selector = ChapterSelectorService.new
    chapters = selector.select(raw_chapters, volumes: volumes_filter)

    summary = selector.language_summary(chapters)
    summary.each { |lang, count| log!("  #{lang}: #{count} chapters") }
    log!("Selected #{chapters.size} chapters to download")

    # Skip volumes already downloaded for this manga
    already_downloaded = DownloadVolume.where(manga_id: manga_id).pluck(:volume).to_set
    new_chapters = chapters.reject { |ch| already_downloaded.include?(ch[:volume]) }

    if already_downloaded.any?
      skipped = chapters.size - new_chapters.size
      log!("Skipping #{skipped} chapters from #{already_downloaded.size} already downloaded volumes: #{already_downloaded.to_a.sort_by { |v| v.to_f }.join(', ')}")
    end

    if new_chapters.empty?
      log!("All volumes already downloaded")
      @download.update!(status: :completed, progress: 100, completed_at: Time.current)
      broadcast_status
      return
    end

    new_volumes = new_chapters.map { |ch| ch[:volume] }.uniq
    log!("#{new_volumes.size} new volumes to download (#{new_chapters.size} chapters)")

    tmpdir = Dir.mktmpdir("manga_dl_")
    downloader = ImageDownloaderService.new(adapter: @adapter)

    # Count total images across new chapters
    total_images = 0
    chapter_images = {}
    new_chapters.each do |ch|
      return if cancelled?
      count = downloader.count_images(ch[:id])
      chapter_images[ch[:id]] = count
      total_images += count
    end

    log!("Total images to download: #{total_images}")
    downloaded_images = 0
    volume_stats = Hash.new { |h, k| h[k] = { chapters: 0, pages: 0 } }

    new_chapters.each do |ch|
      return if cancelled?

      chdir = File.join(tmpdir, "vol#{ch[:volume]}", "ch#{ch[:chapter].gsub('.', '_')}")
      log!("Ch.#{ch[:chapter]} (Vol.#{ch[:volume]}) — #{chapter_images[ch[:id]]} pages")

      count = downloader.download_chapter(ch[:id], chdir) do
        downloaded_images += 1
        progress = total_images > 0 ? ((downloaded_images.to_f / total_images) * 100).to_i : 0
        @download.update!(progress: progress)
        broadcast_progress(downloaded_images, total_images)
      end

      volume_stats[ch[:volume]][:chapters] += 1
      volume_stats[ch[:volume]][:pages] += count

      log!("  #{count} pages downloaded")
    end

    return if cancelled?

    @download.update!(status: :packing)
    broadcast_status
    log!("Packing volumes...")

    dest = File.join(Setting.fetch(:destination_root, "/downloads"), title)
    packer = CbzPackerService.new
    sorted_volumes = new_volumes.sort_by { |v| v.to_f }

    results = if sorted_volumes.all? { |v| v == "0" }
      packer.pack_single_volume(tmpdir, dest, title)
    else
      packer.pack_volumes(tmpdir, dest, title, sorted_volumes)
    end

    results.each { |r| log!("Vol. #{r[:volume]}: #{r[:pages]} pages") }

    # Record downloaded volumes
    volume_stats.each do |vol, stats|
      @download.download_volumes.create!(
        manga_id: manga_id,
        volume: vol,
        chapters_count: stats[:chapters],
        pages_count: stats[:pages]
      )
    end

    @download.update!(status: :completed, progress: 100, completed_at: Time.current)
    broadcast_status
    log!("Done! Files saved to: #{dest}")
  rescue => e
    @download.update!(status: :failed, error_message: e.message, completed_at: Time.current)
    log!(e.message, level: :error)
    log!(e.backtrace&.first(5)&.join("\n"), level: :error)
    broadcast_status
  ensure
    FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exist?(tmpdir)
  end

  private

  def load_languages
    config = YAML.load_file(Rails.root.join("config", "languages.yml"))
    config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
  end

  def parse_volumes(volumes_str)
    return nil if volumes_str.blank?

    volumes_str.split(",").map(&:strip).reject(&:blank?)
  end

  def cancelled?
    @download.reload.cancelled?
  end

  def log!(message, level: :info)
    @download.log!(message, level: level)
  end

  def broadcast_status
    ActionCable.server.broadcast("download_#{@download.id}", {
      type: "status_changed",
      download_id: @download.id,
      status: @download.status,
      title: @download.title,
      progress: @download.progress,
      error_message: @download.error_message
    })
  end

  def broadcast_progress(downloaded, total)
    ActionCable.server.broadcast("download_#{@download.id}", {
      type: "progress_updated",
      download_id: @download.id,
      progress: @download.progress,
      downloaded_images: downloaded,
      total_images: total
    })
  end
end
