class DownloadOrchestratorService
  include Interactor::Organizer

  extend InteractorStepDefinitions

  step DownloadOrchestratorSteps::FetchMangaInfoStep,
       dependencies: {
         adapter: -> (ctx) { AdapterRegistry.for_url(ctx[:download].url) }
       }

  step DownloadOrchestratorSteps::SelectChaptersStep,
       dependencies: {
         selector:  -> { ChapterSelectorService.new },
         languages: -> { LanguageLoader.codes }
       }

  step DownloadOrchestratorSteps::DownloadImagesStep,
       dependencies: {
         file_manager: -> { FileManager.new },
         downloader:   -> (ctx) { ImageDownloaderService.new(adapter: ctx[:adapter], file_manager: ctx[:file_manager]) }
       }

  step DownloadOrchestratorSteps::PackVolumesStep,
       dependencies: {
         packer: -> (ctx) { CbzPackerService.new(file_manager: ctx[:file_manager]) }
       }

  step DownloadOrchestratorSteps::RecordVolumesStep

  dependency observers: -> { [DownloadBroadcastObserver.new] }

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

  def initialize(context = {})
    resolved = context.dup
    self.class.dependencies.each do |key, factory|
      next if resolved.key?(key)
      resolved[key] = resolve_factory(factory, resolved)
    end
    super(resolved)
  end

  def call
    self.class.step_definitions.each do |step_class, deps|
      deps.each do |key, factory|
        context[key] ||= resolve_factory(factory, context)
      end
      step_class.call!(context)
      context.observers.each { |o| o.on_status_changed(context) }
    end
  end

  private

  def resolve_factory(factory, ctx)
    return factory unless factory.respond_to?(:call)
    factory.arity == 0 ? factory.call : factory.call(ctx)
  end
end
