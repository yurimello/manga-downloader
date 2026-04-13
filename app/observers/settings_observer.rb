class SettingsObserver
  def self.validation_failed(errors)
    ActionCable.server.broadcast("settings", {
      type: "validation_error",
      errors: errors
    })
  end

  def self.saved(key)
    ActionCable.server.broadcast("settings", {
      type: "saved",
      key: key
    })
  end
end
