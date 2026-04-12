require "rails_helper"

RSpec.describe DownloadMangaCommand do
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  before do
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
    allow(DownloadMangaJob).to receive(:perform_async)
  end

  describe "#call" do
    it "creates a download and enqueues job" do
      command = described_class.new(
        url: "https://mangadex.org/title/abc-123/test"
      ).call

      expect(command).to be_success
      expect(command.result).to be_a(Download)
      expect(command.result.status).to eq("queued")
      expect(DownloadMangaJob).to have_received(:perform_async).with(command.result.id)
    end

    it "saves volumes" do
      command = described_class.new(
        url: "https://mangadex.org/title/abc-123/test",
        volumes: "1, 2, 3"
      ).call

      expect(command.result.volumes).to eq("1, 2, 3")
    end

    it "fails with blank URL" do
      command = described_class.new(url: "").call

      expect(command).not_to be_success
      expect(command.errors).to include("URL is required")
    end

    it "fails with unsupported URL" do
      allow(AdapterRegistry).to receive(:for_url).and_return(nil)

      command = described_class.new(url: "https://unknown.com/test").call

      expect(command).not_to be_success
      expect(command.errors).to include("No adapter found for this URL")
    end
  end
end
