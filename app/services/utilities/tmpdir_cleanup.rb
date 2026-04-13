module Utilities
  class TmpdirCleanup
    def initialize(file_manager: FileManager.new)
      @fs = file_manager
    end

    def call(path)
      @fs.rm_rf(path) if path && @fs.dir_exist?(path)
    end
  end
end
