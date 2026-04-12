require "rails_helper"

RSpec.describe Download, type: :model do
  describe "validations" do
    it { expect(build(:download)).to be_valid }
    it { expect(build(:download, url: nil)).not_to be_valid }
  end

  describe "enums" do
    it "defines status enum" do
      expect(described_class.statuses).to include(
        "queued" => 0, "downloading" => 1, "packing" => 2,
        "completed" => 3, "failed" => 4, "cancelled" => 5
      )
    end
  end

  describe "scopes" do
    let!(:queued) { create(:download) }
    let!(:downloading) { create(:download, :downloading) }
    let!(:completed) { create(:download, :completed) }
    let!(:failed) { create(:download, :failed) }

    it ".active returns queued and downloading" do
      expect(described_class.active).to include(queued, downloading)
      expect(described_class.active).not_to include(completed, failed)
    end

    it ".completed_or_failed returns completed and failed" do
      expect(described_class.completed_or_failed).to include(completed, failed)
      expect(described_class.completed_or_failed).not_to include(queued, downloading)
    end
  end

  describe "#log!" do
    let(:download) { create(:download) }

    it "creates a download log" do
      expect { download.log!("test message") }.to change(DownloadLog, :count).by(1)
    end

    it "broadcasts via ActionCable" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "log_added")
      )
      download.log!("test message")
    end
  end
end
