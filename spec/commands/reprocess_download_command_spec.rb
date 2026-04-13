require "rails_helper"

RSpec.describe ReprocessDownloadCommand do
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  before do
    Setting.store(:destination_root, Dir.mktmpdir)
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
    allow(DownloadMangaJob).to receive(:perform_async)
  end

  describe ".call" do
    it "resolves download and queues a new one" do
      original = create(:download, :completed)

      result = described_class.call(download_id: original.id)

      expect(result).to be_success
      expect(result.download).to be_a(Download)
      expect(result.download.url).to eq(original.url)
      expect(result.download.id).not_to eq(original.id)
      expect(DownloadMangaJob).to have_received(:perform_async)
    end

    it "preserves volumes from original download" do
      original = create(:download, :completed, volumes: "1, 2, 3")

      result = described_class.call(download_id: original.id)

      expect(result.download.volumes).to eq("1, 2, 3")
    end

    it "fails when download not found" do
      result = described_class.call(download_id: 999)

      expect(result).to be_failure
      expect(result.message).to eq("Download not found")
    end

    it "stops chain on first failure" do
      result = described_class.call(download_id: 999)

      expect(result).to be_failure
      expect(DownloadMangaJob).not_to have_received(:perform_async)
    end
  end
end
