class DownloadOrchestratorService
  include Interactor::Organizer

  organize DownloadOrchestratorSteps::FetchMangaInfoStep,
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
    fs = context.file_manager || FileManager.new
    fs.rm_rf(tmpdir) if tmpdir && fs.dir_exist?(tmpdir)
  end

  def call
    self.class.organized.each do |step|
      step.call!(context)
      (context.observers || []).each { |o| o.on_status_changed(context) }
    end
  end
end
