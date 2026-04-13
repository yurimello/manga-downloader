class FileManager
  def join(*parts)
    File.join(*parts)
  end

  def dirname(path)
    File.dirname(path)
  end

  def extname(path)
    File.extname(path)
  end

  def binwrite(path, data)
    File.binwrite(path, data)
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(path)
  end

  def rm_f(path)
    FileUtils.rm_f(path)
  end

  def rm_rf(path)
    FileUtils.rm_rf(path)
  end

  def mktmpdir(prefix)
    Dir.mktmpdir(prefix)
  end

  def directory?(path)
    File.directory?(path)
  end

  def writable?(path)
    File.writable?(path)
  end

  def dir_exist?(path)
    Dir.exist?(path)
  end

  def glob(pattern)
    Dir.glob(pattern).sort
  end

  def images_in(dir)
    glob(join(dir, "*.{jpg,jpeg,png,webp}"))
  end
end
