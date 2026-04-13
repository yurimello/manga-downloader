class DownloadsController < ApplicationController
  def index
    @active_downloads = Download.active.order(created_at: :desc)
    @completed_downloads = Download.completed_or_failed.order(completed_at: :desc).limit(20)
    @sources = AdapterRegistry.instance.sources
  end

  def create
    result = ProcessDownloadCommand.call(
      url: params[:url],
      volumes: params[:volumes].presence
    )

    if result.success?
      redirect_to root_path, notice: "Download queued!"
    else
      redirect_to root_path, alert: result.message
    end
  end

  def reprocess
    result = ReprocessDownloadCommand.call(download_id: params[:id])

    if result.success?
      redirect_to root_path, notice: "Reprocessing queued!"
    else
      redirect_to root_path, alert: result.message
    end
  end

  def destroy
    download = Download.find(params[:id])

    if download.active?
      download.update!(status: :cancelled)
      redirect_to root_path, notice: "Download cancelled."
    else
      download.destroy
      redirect_to root_path, notice: "Download removed."
    end
  end
end
