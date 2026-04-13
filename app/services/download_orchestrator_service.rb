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
    context.download.update!(status: :failed, error_message: e.message, completed_at: Time.current)
    context.download.log!(e.message, level: :error)
    context.download.log!(e.backtrace&.first(5)&.join("\n"), level: :error)
    observers.each { |o| o.on_error(context, e) }
    context.fail!(error: e)
  ensure
    tmpdir = context.tmpdir
    context.file_manager.rm_rf(tmpdir) if tmpdir && context.file_manager&.dir_exist?(tmpdir)
  end

  def call
    self.class.organized.each do |step|
      step.call!(context)
      observers.each { |o| o.on_status_changed(context) }
    end
  end

  private

  def observers
    @observers ||= context.observers || []
  end
end
