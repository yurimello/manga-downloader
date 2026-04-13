class ContextObserver
  def on_status_changed(source) = nil
  def on_progress_updated(source, progress) = nil
  def on_log_added(source, message, level) = nil
  def on_error(source, error) = nil
end
