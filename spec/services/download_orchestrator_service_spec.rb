require "rails_helper"

RSpec.describe DownloadOrchestratorService do
  let(:download) { create(:download) }
  let(:adapter) { instance_double(MangadexAdapter) }
  let(:selector) { ChapterSelectorService.new }
  let(:downloader) { ImageDownloaderService.new(adapter: adapter) }
  let(:packer) { CbzPackerService.new }
  let(:observer) { DownloadBroadcastObserver.new }

  before do
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

  def run_orchestrator(dest_dir: nil)
    dir = dest_dir || Dir.mktmpdir
    allow(Setting).to receive(:fetch).and_return(dir)

    described_class.call(
      download: download,
      adapter: adapter,
      selector: selector,
      downloader: downloader,
      packer: packer,
      observers: [observer]
    )
  end

  describe "#call" do
    it "completes successfully" do
      Dir.mktmpdir do |dir|
        run_orchestrator(dest_dir: dir)

        download.reload
        expect(download.status).to eq("completed")
        expect(download.title).to eq("Test Manga")
        expect(download.progress).to eq(100)
      end
    end

    it "sets status to failed on error" do
      allow(adapter).to receive(:extract_manga_id).and_raise(StandardError, "boom")

      run_orchestrator

      download.reload
      expect(download.status).to eq("failed")
      expect(download.error_message).to eq("boom")
    end

    it "broadcasts image-level progress via observer" do
      Dir.mktmpdir do |dir|
        run_orchestrator(dest_dir: dir)
      end

      expect(ActionCable.server).to have_received(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "progress_updated", :downloaded_images => a_kind_of(Integer), :total_images => a_kind_of(Integer))
      ).at_least(:once)
    end

    it "broadcasts status changes via observer" do
      Dir.mktmpdir do |dir|
        run_orchestrator(dest_dir: dir)
      end

      expect(ActionCable.server).to have_received(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "status_changed", status: "downloading")
      ).at_least(:once)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "status_changed", status: "packing")
      ).once

      expect(ActionCable.server).to have_received(:broadcast).with(
        "download_#{download.id}",
        hash_including(type: "status_changed", status: "completed")
      ).once
    end

    it "creates log entries" do
      Dir.mktmpdir do |dir|
        run_orchestrator(dest_dir: dir)
      end

      expect(download.download_logs.count).to be > 0
    end
  end
end
