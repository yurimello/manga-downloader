class DownloadOrchestratorService
  include Interactor::Organizer

  organize DownloadOrchestratorSteps::FetchMangaInfoStep,
           DownloadOrchestratorSteps::SelectChaptersStep,
           DownloadOrchestratorSteps::DownloadImagesStep,
           DownloadOrchestratorSteps::PackVolumesStep,
           DownloadOrchestratorSteps::RecordVolumesStep

  def initialize(context = {})
    super(context)
    context = self.context
    context.adapter       ||= AdapterRegistry.for_url(context.download.url)
    context.file_manager  ||= FileManager.new
    context.selector      ||= ChapterSelectorService.new
    context.downloader    ||= ImageDownloaderService.new(adapter: context.adapter, file_manager: context.file_manager)
    context.packer        ||= CbzPackerService.new(file_manager: context.file_manager)
    context.languages     ||= load_languages
    context.observers     ||= [DownloadBroadcastObserver.new]
  end

  around do |interactor|
    interactor.call
  rescue => e
    context.download.update!(status: :failed, error_message: e.message, completed_at: Time.current)
    context.download.log!(e.message, level: :error)
    context.download.log!(e.backtrace&.first(5)&.join("\n"), level: :error)
    context.observers.each { |o| o.on_error(context, e) }
    context.fail!(error: e)
  ensure
    tmpdir = context.tmpdir
    context.file_manager&.rm_rf(tmpdir) if tmpdir && context.file_manager&.dir_exist?(tmpdir)
  end

  def call
    self.class.organized.each do |step|
      step.call!(context)
      context.observers.each { |o| o.on_status_changed(context) }
    end
  end

  private

  def load_languages
    config = YAML.load_file(Rails.root.join("config", "languages.yml"))
    config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
  end
end
