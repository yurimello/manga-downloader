class DownloadMangaCommand < BaseCommand
  def call
    url = context.url
    volumes = context.volumes

    if url.blank?
      context.fail!(message: "URL is required")
      return
    end

    adapter = AdapterRegistry.for_url(url)
    unless adapter
      context.fail!(message: "No adapter found for this URL")
      return
    end

    source = AdapterRegistry.instance.sources.find { |s| AdapterRegistry.for_source(s)&.url_pattern&.match?(url) }

    download = Download.create!(
      url: url,
      volumes: volumes,
      status: :queued,
      source: source
    )

    DownloadMangaJob.perform_async(download.id)
    context.download = download
  end
end
