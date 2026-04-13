module DownloadOrchestratorSteps
  class RecordVolumesStep < BaseStep
    def call
      return if @context[:completed_early]

      manga_id = @context[:manga_id]
      volume_stats = @context[:volume_stats]

      volume_stats.each do |vol, stats|
        download.download_volumes.create!(
          manga_id: manga_id,
          volume: vol,
          chapters_count: stats[:chapters],
          pages_count: stats[:pages]
        )
      end

      download.update!(status: :completed, progress: 100, completed_at: Time.current)
      notify_status_changed
      log!("Done! Files saved to: #{File.join(Setting.fetch(:destination_root, '/downloads'), @context[:title])}")
    end
  end
end
