require "rails_helper"

RSpec.describe DownloadMangaJob do
  let(:download) { create(:download) }
  let(:result) { instance_double(Interactor::Context, success?: true) }

  before do
    allow(AdapterRegistry).to receive(:for_url).and_return(instance_double(MangadexAdapter))
    allow(DownloadOrchestratorService).to receive(:call).and_return(result)
  end

  describe "#perform" do
    it "runs the orchestrator with the download" do
      described_class.new.perform(download.id)
      expect(DownloadOrchestratorService).to have_received(:call).with(
        hash_including(download: download)
      )
    end

    it "skips cancelled downloads" do
      download.update!(status: :cancelled)
      described_class.new.perform(download.id)
      expect(DownloadOrchestratorService).not_to have_received(:call)
    end

    it "re-enqueues when at max capacity" do
      Setting.store(:max_concurrent_processes, "1")
      create(:download, :downloading)

      expect(described_class).to receive(:perform_in).with(10, download.id)
      described_class.new.perform(download.id)
      expect(DownloadOrchestratorService).not_to have_received(:call)
    end
  end
end
