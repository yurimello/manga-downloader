class BaseStep
  include Interactor

  private

  def download
    context.download
  end

  def log!(message, level: :info)
    download.log!(message, level: level)
    notify_observers(:on_log_added, message, level)
  end

  def notify_observers(event, *args)
    (context.observers || []).each { |o| o.public_send(event, context, *args) }
  end

  def cancelled?
    download.reload.cancelled?
  end
end
