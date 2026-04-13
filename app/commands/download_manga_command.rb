class DownloadMangaCommand < BaseCommand
  def call
    url = @context[:url]
    volumes = @context[:volumes]

    if url.blank?
      add_error("URL is required")
      return self
    end

    adapter = AdapterRegistry.for_url(url)
    unless adapter
      add_error("No adapter found for this URL")
      return self
    end

    source = AdapterRegistry.instance.sources.find { |s| AdapterRegistry.for_source(s)&.url_pattern&.match?(url) }

    download = Download.create!(
      url: url,
      volumes: volumes,
      status: :queued,
      source: source
    )

    DownloadMangaJob.perform_async(download.id)
    @result = download
    self
  end
end
