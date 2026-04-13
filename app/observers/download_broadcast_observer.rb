class DownloadBroadcastObserver < ContextObserver
  def on_status_changed(context)
    download = context[:download]
    return unless download

    ActionCable.server.broadcast("download_#{download.id}", {
      type: "status_changed",
      download_id: download.id,
      status: download.status,
      title: download.title,
      progress: download.progress,
      error_message: download.error_message
    })
  end

  def on_progress_updated(context)
    download = context[:download]
    return unless download

    ActionCable.server.broadcast("download_#{download.id}", {
      type: "progress_updated",
      download_id: download.id,
      progress: download.progress,
      downloaded_images: context[:downloaded_images],
      total_images: context[:total_images]
    })
  end

  def on_error(context, error)
    download = context[:download]
    return unless download

    download.update!(status: :failed, error_message: error.message, completed_at: Time.current)
    download.log!(error.message, level: :error)
    download.log!(error.backtrace&.first(5)&.join("\n"), level: :error)

    on_status_changed(context)
  end
end
