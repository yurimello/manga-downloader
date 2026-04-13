module DownloadOrchestratorSteps
  class DownloadImagesStep < BaseStep
    def call
      return if @context[:completed_early]

      chapters = @context[:chapters]
      downloader = @context[:downloader]
      tmpdir = Dir.mktmpdir("manga_dl_")
      @context[:tmpdir] = tmpdir

      # Count total images
      total_images = 0
      chapter_images = {}
      chapters.each do |ch|
        return if download.reload.cancelled?
        count = downloader.count_images(ch[:id])
        chapter_images[ch[:id]] = count
        total_images += count
      end

      log!("Total images to download: #{total_images}")
      downloaded_images = 0
      volume_stats = Hash.new { |h, k| h[k] = { chapters: 0, pages: 0 } }

      chapters.each do |ch|
        return if download.reload.cancelled?

        chdir = File.join(tmpdir, "vol#{ch[:volume]}", "ch#{ch[:chapter].gsub('.', '_')}")
        log!("Ch.#{ch[:chapter]} (Vol.#{ch[:volume]}) — #{chapter_images[ch[:id]]} pages")

        count = downloader.download_chapter(ch[:id], chdir) do
          downloaded_images += 1
          progress = total_images > 0 ? ((downloaded_images.to_f / total_images) * 100).to_i : 0
          download.update!(progress: progress)
          @context[:downloaded_images] = downloaded_images
          @context[:total_images] = total_images
          notify_progress_updated
        end

        volume_stats[ch[:volume]][:chapters] += 1
        volume_stats[ch[:volume]][:pages] += count

        log!("  #{count} pages downloaded")
      end

      @context[:volume_stats] = volume_stats
    end
  end
end
