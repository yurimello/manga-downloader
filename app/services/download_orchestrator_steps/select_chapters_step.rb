module DownloadOrchestratorSteps
  class SelectChaptersStep < BaseStep
    def call
      adapter = @context[:adapter]
      selector = @context[:selector]
      manga_id = @context[:manga_id]

      languages = load_languages
      log!("Fetching chapters...")
      raw_chapters = adapter.fetch_chapters(manga_id, languages: languages)
      log!("Found #{raw_chapters.size} total chapters across all languages")

      volumes_filter = parse_volumes(download.volumes)
      chapters = selector.select(raw_chapters, volumes: volumes_filter)

      summary = selector.language_summary(chapters)
      summary.each { |lang, count| log!("  #{lang}: #{count} chapters") }
      log!("Selected #{chapters.size} chapters to download")

      # Skip volumes already downloaded for this manga
      already_downloaded = DownloadVolume.downloaded_volumes_for(manga_id)
      new_chapters = chapters.reject { |ch| already_downloaded.include?(ch[:volume]) }

      if already_downloaded.any?
        skipped = chapters.size - new_chapters.size
        log!("Skipping #{skipped} chapters from #{already_downloaded.size} already downloaded volumes: #{already_downloaded.to_a.sort_by { |v| v.to_f }.join(', ')}")
      end

      if new_chapters.empty?
        log!("All volumes already downloaded")
        download.update!(status: :completed, progress: 100, completed_at: Time.current)
        broadcast_status
        @context[:completed_early] = true
        return
      end

      log!("#{new_chapters.map { |ch| ch[:volume] }.uniq.size} new volumes to download (#{new_chapters.size} chapters)")

      @context[:chapters] = new_chapters
    end

    private

    def load_languages
      config = YAML.load_file(Rails.root.join("config", "languages.yml"))
      config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
    end

    def parse_volumes(volumes_str)
      return nil if volumes_str.blank?
      volumes_str.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
