class ProcessDownloadCommand
  include Interactor::Organizer

  organize ValidateDestinationCommand, DownloadMangaCommand
end
