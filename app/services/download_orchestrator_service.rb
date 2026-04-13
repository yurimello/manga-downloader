class DownloadOrchestratorService
  STEPS = [
    DownloadOrchestratorSteps::FetchMangaInfoStep,
    DownloadOrchestratorSteps::SelectChaptersStep,
    DownloadOrchestratorSteps::DownloadImagesStep,
    DownloadOrchestratorSteps::PackVolumesStep,
    DownloadOrchestratorSteps::RecordVolumesStep
  ].freeze

  def initialize(download, adapter:, selector:, downloader:, packer:, observers: [])
    @context = {
      download: download,
      adapter: adapter,
      selector: selector,
      downloader: downloader,
      packer: packer
    }
    @observers = observers
  end

  def call
    ServicePipeline.new(STEPS, @context, observers: @observers).call
  ensure
    tmpdir = @context[:tmpdir]
    FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exist?(tmpdir)
  end
end
