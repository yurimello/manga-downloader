class BaseStep
  include Interactor

  private

  def download
    context.download
  end

  def log!(message, level: :info)
    download.log!(message, level: level)
  end

  def notify_status_changed
    (context.observers || []).each { |o| o.on_status_changed(context) }
  end

  def notify_progress_updated
    (context.observers || []).each { |o| o.on_progress_updated(context) }
  end

  def cancelled?
    download.reload.cancelled?
  end
end
