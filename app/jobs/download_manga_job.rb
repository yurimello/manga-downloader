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

    DownloadOrchestratorService.new(
      download,
      adapter: adapter,
      selector: ChapterSelectorService.new,
      downloader: ImageDownloaderService.new(adapter: adapter),
      packer: CbzPackerService.new,
      observers: [DownloadBroadcastObserver.new]
    ).call
  end
end
