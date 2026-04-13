import consumer from "channels/consumer"

const subscriptions = {}

export function subscribeToDownload(downloadId, callbacks) {
  if (subscriptions[downloadId]) return

  subscriptions[downloadId] = consumer.subscriptions.create(
    { channel: "DownloadChannel", id: downloadId },
    {
      received(data) {
        switch (data.type) {
          case "progress_updated":
            callbacks.onProgress?.(data)
            break
          case "log_added":
            callbacks.onLog?.(data)
            break
          case "status_changed":
            callbacks.onStatus?.(data)
            break
        }
      }
    }
  )
}

export function unsubscribeFromDownload(downloadId) {
  if (subscriptions[downloadId]) {
    subscriptions[downloadId].unsubscribe()
    delete subscriptions[downloadId]
  }
}
