class ResolveDownloadCommand < BaseCommand
  def call
    download = Download.find_by(id: context.download_id)

    unless download
      context.fail!(message: "Download not found")
      return
    end

    context.url = download.url
    context.volumes = download.volumes
  end
end
