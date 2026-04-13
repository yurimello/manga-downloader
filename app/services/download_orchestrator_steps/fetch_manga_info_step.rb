module DownloadOrchestratorSteps
  class FetchMangaInfoStep < BaseStep
    def call
      download.update!(status: :downloading, started_at: Time.current)
      notify_status_changed

      adapter = @context[:adapter]
      manga_id = adapter.extract_manga_id(download.url)
      log!("Extracted manga ID: #{manga_id}")

      title = adapter.fetch_manga_title(manga_id)
      download.update!(title: title, manga_id: manga_id)
      log!("Title: #{title}")
      notify_status_changed

      @context[:manga_id] = manga_id
      @context[:title] = title
    end
  end
end
