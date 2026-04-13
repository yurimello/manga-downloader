import consumer from "channels/consumer"

let subscription = null

export function subscribeToSettings(callbacks) {
  if (subscription) return

  subscription = consumer.subscriptions.create(
    { channel: "SettingsChannel" },
    {
      received(data) {
        switch (data.type) {
          case "validation_error":
            callbacks.onValidationError?.(data)
            break
          case "saved":
            callbacks.onSaved?.(data)
            break
        }
      }
    }
  )
}

export function unsubscribeFromSettings() {
  if (subscription) {
    subscription.unsubscribe()
    subscription = null
  }
}
