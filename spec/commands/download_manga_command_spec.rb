require "rails_helper"

RSpec.describe DownloadMangaCommand do
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  before do
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
    allow(DownloadMangaJob).to receive(:perform_async)
  end

  describe ".call" do
    it "creates a download and enqueues job" do
      result = described_class.call(url: "https://mangadex.org/title/abc-123/test")

      expect(result).to be_success
      expect(result.download).to be_a(Download)
      expect(result.download.status).to eq("queued")
      expect(DownloadMangaJob).to have_received(:perform_async).with(result.download.id)
    end

    it "saves volumes" do
      result = described_class.call(url: "https://mangadex.org/title/abc-123/test", volumes: "1, 2, 3")

      expect(result.download.volumes).to eq("1, 2, 3")
    end

    it "fails with blank URL" do
      result = described_class.call(url: "")

      expect(result).to be_failure
      expect(result.message).to eq("URL is required")
    end

    it "fails with unsupported URL" do
      allow(AdapterRegistry).to receive(:for_url).and_return(nil)

      result = described_class.call(url: "https://unknown.com/test")

      expect(result).to be_failure
      expect(result.message).to eq("No adapter found for this URL")
    end
  end
end
