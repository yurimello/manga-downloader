module Observable
  def add_observer(observer)
    observers << observer
  end

  def observers
    @observers ||= []
  end

  def notify(event, *args)
    observers.each { |o| o.public_send(event, self, *args) }
  end
end
