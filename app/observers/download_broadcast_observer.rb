class DownloadBroadcastObserver < ContextObserver
  def on_status_changed(context)
    return unless context.download

    ActionCable.server.broadcast("download_#{context.download.id}", {
      type: "status_changed",
      download_id: context.download.id,
      status: context.download.status,
      title: context.download.title,
      progress: context.download.progress,
      error_message: context.download.error_message
    })
  end

  def on_progress_updated(context)
    return unless context.download

    ActionCable.server.broadcast("download_#{context.download.id}", {
      type: "progress_updated",
      download_id: context.download.id,
      progress: context.download.progress,
      downloaded_images: context.downloaded_images,
      total_images: context.total_images
    })
  end

  def on_log_added(context, message, level)
    return unless context.download

    ActionCable.server.broadcast("download_#{context.download.id}", {
      type: "log_added",
      download_id: context.download.id,
      message: message,
      level: level.to_s
    })
  end

  def on_error(context, error)
    if context.download
      on_status_changed(context)
    else
      ActionCable.server.broadcast("notifications", {
        type: "error",
        message: error.message
      })
    end
  end
end
