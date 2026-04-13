module ServiceUtils
  class TmpdirCleanup
    def call(path)
      SystemUtils.rm_rf(path) if path && SystemUtils.dir_exist?(path)
    end
  end
end
