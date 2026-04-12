class DownloadMangaCommand < BaseCommand
  def initialize(url:, volumes: nil)
    super()
    @url = url
    @volumes = volumes
  end

  def call
    validate!
    return self unless success?

    adapter = AdapterRegistry.for_url(@url)
    source = AdapterRegistry.instance.sources.find { |s| AdapterRegistry.for_source(s)&.url_pattern&.match?(@url) }

    download = Download.create!(
      url: @url,
      volumes: @volumes,
      status: :queued,
      source: source
    )

    DownloadMangaJob.perform_async(download.id)
    @result = download
    self
  end

  private

  def validate!
    add_error("URL is required") if @url.blank?
    add_error("No adapter found for this URL") if @url.present? && AdapterRegistry.for_url(@url).nil?
  end
end
