class ContextObserver
  def on_status_changed(context) = nil
  def on_progress_updated(context) = nil
  def on_log_added(context, message, level) = nil
  def on_error(context, error) = nil
end
