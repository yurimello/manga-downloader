module DownloadOrchestratorSteps
  class FetchMangaInfoStep < BaseStep
    def call
      download.update!(status: :downloading, started_at: Time.current)

      manga_id = context.adapter.extract_manga_id(download.url)
      log!("Extracted manga ID: #{manga_id}")

      title = context.adapter.fetch_manga_title(manga_id)
      download.update!(title: title, manga_id: manga_id)
      log!("Title: #{title}")

      context.manga_id = manga_id
      context.title = title
    end
  end
end
