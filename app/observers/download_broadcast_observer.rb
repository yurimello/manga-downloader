class DownloadBroadcastObserver < ContextObserver
  def on_status_changed(download)
    ActionCable.server.broadcast("download_#{download.id}", {
      type: "status_changed",
      download_id: download.id,
      status: download.status,
      title: download.title,
      progress: download.progress,
      error_message: download.error_message
    })
  end

  def on_progress_updated(download)
    ActionCable.server.broadcast("download_#{download.id}", {
      type: "progress_updated",
      download_id: download.id,
      progress: download.progress
    })
  end

  def on_log_added(download, message, level)
    ActionCable.server.broadcast("download_#{download.id}", {
      type: "log_added",
      download_id: download.id,
      message: message,
      level: level.to_s
    })
  end

  def on_error(source, error)
    if source.is_a?(Download)
      on_status_changed(source)
    else
      ActionCable.server.broadcast("notifications", {
        type: "error",
        message: error.message
      })
    end
  end
end
