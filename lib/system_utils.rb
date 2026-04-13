module SystemUtils
  def self.join(*parts)
    File.join(*parts)
  end

  def self.dirname(path)
    File.dirname(path)
  end

  def self.extname(path)
    File.extname(path)
  end

  def self.binwrite(path, data)
    File.binwrite(path, data)
  end

  def self.mkdir_p(path)
    FileUtils.mkdir_p(path)
  end

  def self.rm_f(path)
    FileUtils.rm_f(path)
  end

  def self.rm_rf(path)
    FileUtils.rm_rf(path)
  end

  def self.mktmpdir(prefix)
    Dir.mktmpdir(prefix)
  end

  def self.directory?(path)
    File.directory?(path)
  end

  def self.writable?(path)
    File.writable?(path)
  end

  def self.dir_exist?(path)
    Dir.exist?(path)
  end

  def self.glob(pattern)
    Dir.glob(pattern).sort
  end

  def self.images_in(dir)
    glob(join(dir, "*.{jpg,jpeg,png,webp}"))
  end
end
