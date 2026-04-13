class ResolveDownloadCommand < BaseCommand
  def call
    download = Download.find_by(id: @context[:download_id])

    unless download
      add_error("Download not found")
      return self
    end

    @context[:url] = download.url
    @context[:volumes] = download.volumes
    self
  end
end
