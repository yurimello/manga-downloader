class TmpdirCleanupService
  def initialize(file_manager:)
    @fs = file_manager
  end

  def call(path)
    @fs.rm_rf(path) if path && @fs.dir_exist?(path)
  end
end
