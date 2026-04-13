class CreateDownloadCommand
  include Interactor::Organizer

  organize ValidateDestinationCommand, DownloadMangaCommand
end
