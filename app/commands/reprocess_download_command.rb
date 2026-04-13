class ReprocessDownloadCommand
  include Interactor::Organizer

  organize ResolveDownloadCommand, ValidateDestinationCommand, DownloadMangaCommand
end
