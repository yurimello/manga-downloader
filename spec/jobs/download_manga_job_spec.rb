require "rails_helper"

RSpec.describe DownloadMangaJob do
  let(:download) { create(:download) }
  let(:result) { instance_double(Interactor::Context, success?: true) }

  before do
    allow(DownloadOrchestratorService).to receive(:call).and_return(result)
  end

  describe "#perform" do
    it "runs the orchestrator" do
      described_class.new.perform(download.id)
      expect(DownloadOrchestratorService).to have_received(:call).with(
        hash_including(
          download: download,
          adapter: anything,
          selector: a_kind_of(ChapterSelectorService),
          downloader: a_kind_of(ImageDownloaderService),
          packer: a_kind_of(CbzPackerService),
          observers: [a_kind_of(DownloadBroadcastObserver)]
        )
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
