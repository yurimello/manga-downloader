class BaseStep
  def initialize(context)
    @context = context
  end

  def call
    raise NotImplementedError
  end

  private

  def download
    @context[:download]
  end

  def log!(message, level: :info)
    download.log!(message, level: level)
  end

  def broadcast_status
    ActionCable.server.broadcast("download_#{download.id}", {
      type: "status_changed",
      download_id: download.id,
      status: download.status,
      title: download.title,
      progress: download.progress,
      error_message: download.error_message
    })
  end

  def broadcast_progress(downloaded, total)
    ActionCable.server.broadcast("download_#{download.id}", {
      type: "progress_updated",
      download_id: download.id,
      progress: download.progress,
      downloaded_images: downloaded,
      total_images: total
    })
  end
end
