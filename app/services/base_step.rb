class BaseStep
  def initialize(context, observers: [])
    @context = context
    @observers = observers
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

  def notify_status_changed
    @observers.each { |o| o.on_status_changed(@context) }
  end

  def notify_progress_updated
    @observers.each { |o| o.on_progress_updated(@context) }
  end
end
