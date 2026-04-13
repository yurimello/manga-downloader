class ReprocessDownloadCommand
  include Interactor::Organizer

  organize ResolveDownloadCommand, ValidateDestinationCommand, DownloadMangaCommand

  before do
    context.observers ||= [DownloadBroadcastObserver.new]
  end
end
