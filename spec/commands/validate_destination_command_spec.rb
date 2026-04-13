require "rails_helper"

RSpec.describe ValidateDestinationCommand do
  describe ".call" do
    it "passes when destination is configured" do
      Setting.store(:destination_root, "/downloads")
      result = described_class.call

      expect(result).to be_success
    end

    it "fails and notifies when destination is not configured" do
      allow(ActionCable.server).to receive(:broadcast)

      result = described_class.call(observers: [DownloadBroadcastObserver.new])

      expect(result).to be_failure
      expect(result.message).to include("not configured")
      expect(ActionCable.server).to have_received(:broadcast).with(
        "notifications",
        hash_including(type: "error")
      )
    end
  end
end
