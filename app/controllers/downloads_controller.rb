class DownloadsController < ApplicationController
  def index
    @active_downloads = Download.active.order(created_at: :desc)
    @completed_downloads = Download.completed_or_failed.order(completed_at: :desc).limit(20)
  end

  def create
    command = DownloadMangaCommand.new(
      url: params[:url],
      volumes: params[:volumes].presence
    ).call


    if command.success?
      redirect_to root_path, notice: "Download queued!"
    else
      redirect_to root_path, alert: command.errors.join(", ")
    end
  end

  def reprocess
    command = ReprocessDownloadCommand.new(download_id: params[:id]).call

    if command.success?
      redirect_to root_path, notice: "Reprocessing queued!"
    else
      redirect_to root_path, alert: command.errors.join(", ")
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
