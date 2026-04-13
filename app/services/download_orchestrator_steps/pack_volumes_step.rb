module DownloadOrchestratorSteps
  class PackVolumesStep < BaseStep
    after { notify_observers(:on_status_changed) }
    def call
      return if context.completed_early

      download.update!(status: :packing)
      log!("Packing volumes...")

      dest = File.join(Setting.fetch(:destination_root, "/downloads"), context.title)
      volumes = context.chapters.map { |ch| ch[:volume] }.uniq.sort_by { |v| v.to_f }

      results = if volumes.all? { |v| v == "0" }
        context.packer.pack_single_volume(context.tmpdir, dest, context.title)
      else
        context.packer.pack_volumes(context.tmpdir, dest, context.title, volumes)
      end

      results.each { |r| log!("Vol. #{r[:volume]}: #{r[:pages]} pages") }
    end
  end
end
