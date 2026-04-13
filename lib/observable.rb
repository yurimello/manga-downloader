module Observable
  def self.included(base)
    base.after_update :notify_observers_on_change
    base.after_validation :notify_observers_on_validation_error, if: -> { errors.any? }
  end

  def add_observer(observer)
    observers << observer
  end

  def observers
    @observers ||= []
  end

  private

  def notify_observers_on_change
    notify(:on_status_changed) if saved_change_to_attribute?("status")
    notify(:on_progress_updated) if saved_change_to_attribute?("progress")
  end

  def notify_observers_on_validation_error
    notify(:on_validation_error, errors.full_messages)
  end

  def notify(event, *args)
    observers.each { |o| o.public_send(event, self, *args) }
  end
end
