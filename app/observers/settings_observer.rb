class SettingsObserver < ContextObserver
  def on_validation_error(setting, errors)
    ActionCable.server.broadcast("settings", {
      type: "validation_error",
      errors: errors
    })
  end
end
