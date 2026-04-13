class DownloadOrchestratorService < ServicePipeline
  steps DownloadOrchestratorSteps::FetchMangaInfoStep,
        DownloadOrchestratorSteps::SelectChaptersStep,
        DownloadOrchestratorSteps::DownloadImagesStep,
        DownloadOrchestratorSteps::PackVolumesStep,
        DownloadOrchestratorSteps::RecordVolumesStep

  around do |interactor|
    interactor.call
  rescue => e
    (context.observers || []).each { |o| o.on_error(context, e) }
    context.fail!(error: e)
  ensure
    tmpdir = context.tmpdir
    FileUtils.rm_rf(tmpdir) if tmpdir && Dir.exist?(tmpdir)
  end
end
