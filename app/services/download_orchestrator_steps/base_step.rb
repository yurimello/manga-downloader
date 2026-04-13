module DownloadOrchestratorSteps
  class BaseStep
    include Interactor

    private

    def download
      context.download
    end

    def log!(message, level: :info)
      download.log!(message, level: level)
      (context.observers || []).each { |o| o.on_log_added(context, message, level) }
    end
  end
end
