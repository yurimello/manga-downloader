class SettingsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "settings"
  end

  def unsubscribed
  end
end
