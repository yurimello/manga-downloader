class ReprocessDownloadCommand < BaseCommand
  def call
    chain = ResolveDownloadCommand.new(@context).call.then(DownloadMangaCommand)
    @errors = chain.errors
    @result = chain.result
    self
  end
end
