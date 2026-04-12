require "rails_helper"

RSpec.describe DownloadOrchestratorService do
  let(:download) { create(:download) }
  let(:adapter) { instance_double(MangadexAdapter) }

  before do
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    allow(adapter).to receive(:extract_manga_id).and_return("abc-123")
    allow(adapter).to receive(:fetch_manga_title).and_return("Test Manga")
    allow(adapter).to receive(:fetch_chapters).and_return([
      { id: "ch1", chapter: "1", volume: "1", language: "pt-br" },
      { id: "ch2", chapter: "2", volume: "1", language: "pt-br" }
    ])
    allow(adapter).to receive(:fetch_chapter_images).and_return({
      base_url: "https://cdn.example.com",
      hash: "abc",
      filenames: ["page1.jpg"]
    })
    allow(adapter).to receive(:image_url).and_return("https://cdn.example.com/data/abc/page1.jpg")

    stub_request(:get, "https://cdn.example.com/data/abc/page1.jpg")
      .to_return(status: 200, body: "fake_image_data")

    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#call" do
    it "completes successfully" do
      Dir.mktmpdir do |dir|
        allow(Setting).to receive(:fetch).and_return(dir)
        service = described_class.new(download)
        service.call

        download.reload
        expect(download.status).to eq("completed")
        expect(download.title).to eq("Test Manga")
        expect(download.progress).to eq(100)
      end
    end

    it "sets status to failed on error" do
      allow(adapter).to receive(:extract_manga_id).and_raise(StandardError, "boom")

      service = described_class.new(download)
      service.call

      download.reload
      expect(download.status).to eq("failed")
      expect(download.error_message).to eq("boom")
    end

    it "broadcasts progress" do
      service = described_class.new(download)

      Dir.mktmpdir do |dir|
        allow(Setting).to receive(:fetch).with(:destination_root, anything).and_return(dir)
        service.call
      end

      expect(ActionCable.server).to have_received(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "progress_updated")
      ).at_least(:once)
    end

    it "creates log entries" do
      service = described_class.new(download)

      Dir.mktmpdir do |dir|
        allow(Setting).to receive(:fetch).with(:destination_root, anything).and_return(dir)
        service.call
      end

      expect(download.download_logs.count).to be > 0
    end
  end
end
