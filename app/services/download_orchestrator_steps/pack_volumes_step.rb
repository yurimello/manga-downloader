module DownloadOrchestratorSteps
  class PackVolumesStep < BaseStep
    def call
      return if @context[:completed_early]

      download.update!(status: :packing)
      broadcast_status
      log!("Packing volumes...")

      title = @context[:title]
      chapters = @context[:chapters]
      tmpdir = @context[:tmpdir]
      packer = @context[:packer]

      dest = File.join(Setting.fetch(:destination_root, "/downloads"), title)
      volumes = chapters.map { |ch| ch[:volume] }.uniq.sort_by { |v| v.to_f }

      results = if volumes.all? { |v| v == "0" }
        packer.pack_single_volume(tmpdir, dest, title)
      else
        packer.pack_volumes(tmpdir, dest, title, volumes)
      end

      results.each { |r| log!("Vol. #{r[:volume]}: #{r[:pages]} pages") }
    end
  end
end
