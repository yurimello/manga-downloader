class DownloadOrchestratorService
  STEPS = [
    DownloadOrchestratorSteps::FetchMangaInfoStep,
    DownloadOrchestratorSteps::SelectChaptersStep,
    DownloadOrchestratorSteps::DownloadImagesStep,
    DownloadOrchestratorSteps::PackVolumesStep,
    DownloadOrchestratorSteps::RecordVolumesStep
  ].freeze

  def initialize(download, adapter:, selector:, downloader:, packer:)
    @context = {
      download: download,
      adapter: adapter,
      selector: selector,
      downloader: downloader,
      packer: packer
    }
  end

  def call
    pipeline = ServicePipeline.new(STEPS, @context).call

    unless pipeline.success?
      handle_failure(pipeline.error)
    end
  ensure
    tmpdir = @context[:tmpdir]
    FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exist?(tmpdir)
  end

  private

  def handle_failure(error)
    download = @context[:download]
    download.update!(status: :failed, error_message: error.message, completed_at: Time.current)
    download.log!(error.message, level: :error)
    download.log!(error.backtrace&.first(5)&.join("\n"), level: :error)

    ActionCable.server.broadcast("download_#{download.id}", {
      type: "status_changed",
      download_id: download.id,
      status: download.status,
      progress: download.progress,
      error_message: download.error_message
    })
  end
end
