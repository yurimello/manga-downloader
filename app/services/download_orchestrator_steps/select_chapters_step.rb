module DownloadOrchestratorSteps
  class SelectChaptersStep < BaseStep
    def call
      log!("Fetching chapters...")
      raw_chapters = context.adapter.fetch_chapters(context.manga_id, languages: context.languages)
      log!("Found #{raw_chapters.size} total chapters across all languages")

      volumes_filter = parse_volumes(download.volumes)
      chapters = context.selector.select(raw_chapters, volumes: volumes_filter)

      summary = context.selector.language_summary(chapters)
      summary.each { |lang, count| log!("  #{lang}: #{count} chapters") }
      log!("Selected #{chapters.size} chapters to download")

      already_downloaded = DownloadVolume.downloaded_volumes_for(context.manga_id)
      new_chapters = chapters.reject { |ch| already_downloaded.include?(ch[:volume]) }

      if already_downloaded.any?
        skipped = chapters.size - new_chapters.size
        log!("Skipping #{skipped} chapters from #{already_downloaded.size} already downloaded volumes: #{already_downloaded.to_a.sort_by { |v| v.to_f }.join(', ')}")
      end

      if new_chapters.empty?
        log!("All volumes already downloaded")
        download.update!(status: :completed, progress: 100, completed_at: Time.current)
        context.completed_early = true
        return
      end

      log!("#{new_chapters.map { |ch| ch[:volume] }.uniq.size} new volumes to download (#{new_chapters.size} chapters)")

      context.chapters = new_chapters
    end

    private

    def parse_volumes(volumes_str)
      return nil if volumes_str.blank?
      volumes_str.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
