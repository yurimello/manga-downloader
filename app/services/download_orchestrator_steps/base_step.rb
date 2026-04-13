module DownloadOrchestratorSteps
  class BaseStep
    include Interactor

    private

    def download
      context.download
    end

    def log!(message, level: :info)
      download.log!(message, level: level)
    end
  end
end
