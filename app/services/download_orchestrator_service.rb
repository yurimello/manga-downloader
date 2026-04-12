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

    tmpdir = Dir.mktmpdir("manga_dl_")
    downloader = ImageDownloaderService.new(adapter: @adapter)
    total = chapters.size

    chapters.each_with_index do |ch, idx|
      return if cancelled?

      chdir = File.join(tmpdir, "vol#{ch[:volume]}", "ch#{ch[:chapter].gsub('.', '_')}")
      log!("Ch.#{ch[:chapter]} (Vol.#{ch[:volume]})...")

      count = downloader.download_chapter(ch[:id], chdir)
      log!("  #{count} pages downloaded")

      progress = ((idx + 1).to_f / total * 100).to_i
      @download.update!(progress: progress)
      broadcast_progress(idx + 1, total)

      sleep 0.5
    end

    return if cancelled?

    @download.update!(status: :packing)
    broadcast_status
    log!("Packing volumes...")

    dest = File.join(Setting.fetch(:destination_root, File.expand_path("~/Comics/Manga")), title)
    packer = CbzPackerService.new
    volumes = chapters.map { |ch| ch[:volume] }.uniq.sort_by { |v| v.to_f }

    results = if volumes.all? { |v| v == "0" }
      packer.pack_single_volume(tmpdir, dest, title)
    else
      packer.pack_volumes(tmpdir, dest, title, volumes)
    end

    results.each { |r| log!("Vol. #{r[:volume]}: #{r[:pages]} pages") }

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

  def broadcast_progress(current, total)
    ActionCable.server.broadcast("download_#{@download.id}", {
      type: "progress_updated",
      download_id: @download.id,
      progress: @download.progress,
      current_chapter: current,
      total_chapters: total
    })
  end
end
