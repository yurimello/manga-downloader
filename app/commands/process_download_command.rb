class ProcessDownloadCommand
  include Interactor::Organizer

  organize ValidateDestinationCommand, DownloadMangaCommand

  before do
    context.observers ||= [DownloadBroadcastObserver.new]
  end
end
