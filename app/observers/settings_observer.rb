class SettingsObserver < ContextObserver
  def on_error(setting, error)
    ActionCable.server.broadcast("settings", {
      type: "validation_error",
      errors: error.is_a?(Array) ? error : [error.to_s]
    })
  end
end
