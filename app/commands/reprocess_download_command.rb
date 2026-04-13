class ReprocessDownloadCommand
  include Interactor::Organizer

  organize ResolveDownloadCommand, DownloadMangaCommand
end
