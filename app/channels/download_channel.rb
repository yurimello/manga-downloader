class DownloadChannel < ApplicationCable::Channel
  def subscribed
    stream_from "download_#{params[:id]}"
  end

  def unsubscribed
  end
end
