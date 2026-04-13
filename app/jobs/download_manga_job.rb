class DownloadMangaJob
  include Sidekiq::Job
  sidekiq_options queue: "downloads", retry: 1

  def perform(download_id)
    download = Download.find(download_id)
    return if download.cancelled?

    max = Setting.fetch(:max_concurrent_processes, "1").to_i
    active = Download.where(status: [:downloading, :packing]).count

    if active >= max
      download.log!("Queue full (#{active}/#{max}), retrying in 10s...")
      self.class.perform_in(10, download_id)
      return
    end

    adapter = AdapterRegistry.for_url(download.url)
    file_manager = FileManager.new
    languages = load_languages

    DownloadOrchestratorService.call(
      download: download,
      adapter: adapter,
      selector: ChapterSelectorService.new,
      downloader: ImageDownloaderService.new(adapter: adapter, file_manager: file_manager),
      packer: CbzPackerService.new(file_manager: file_manager),
      file_manager: file_manager,
      languages: languages,
      observers: [DownloadBroadcastObserver.new]
    )
  end

  private

  def load_languages
    config = YAML.load_file(Rails.root.join("config", "languages.yml"))
    config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
  end
end
