module DownloadOrchestratorSteps
  class BaseStep
    include Interactor

    private

    def observers
      @observers ||= context.observers || []
    end

    def download
      context.download
    end

    def log!(message, level: :info)
      download.log!(message, level: level)
      observers.each { |o| o.on_log_added(context, message, level) }
    end
  end
end
