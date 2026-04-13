module DownloadOrchestratorSteps
  class RecordVolumesStep < BaseStep
    after { notify_observers(:on_status_changed) }
    def call
      return if context.completed_early

      context.volume_stats.each do |vol, stats|
        download.download_volumes.create!(
          manga_id: context.manga_id,
          volume: vol,
          chapters_count: stats[:chapters],
          pages_count: stats[:pages]
        )
      end

      download.update!(status: :completed, progress: 100, completed_at: Time.current)
      log!("Done! Files saved to: #{File.join(Setting.fetch(:destination_root, '/downloads'), context.title)}")
    end
  end
end
