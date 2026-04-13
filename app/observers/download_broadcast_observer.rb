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

  def on_error(context, error)
    return unless context.download

    context.download.update!(status: :failed, error_message: error.message, completed_at: Time.current)
    context.download.log!(error.message, level: :error)
    context.download.log!(error.backtrace&.first(5)&.join("\n"), level: :error)

    on_status_changed(context)
  end
end
