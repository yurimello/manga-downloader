class CbzPackerService
  def pack_volume(source_dirs, output_path)
    FileUtils.mkdir_p(File.dirname(output_path))
    FileUtils.rm_f(output_path)

    Zip::File.open(output_path, create: true) do |zipfile|
      page_index = 0

      source_dirs.sort.each do |dir|
        next unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "*.{jpg,jpeg,png,webp}")).sort.each do |file|
          page_index += 1
          ext = File.extname(file)
          entry_name = format("%04d%s", page_index, ext)
          zipfile.add(entry_name, file)
        end
      end
    end

    page_index = 0
    Zip::File.open(output_path) { |z| page_index = z.size }
    page_index
  end

  def pack_volumes(tmpdir, dest_dir, title, volumes)
    results = []

    volumes.each do |vol|
      volpad = format("%02d", vol.to_i)
      voldir = File.join(tmpdir, "vol#{vol}")
      next unless Dir.exist?(voldir)

      chapter_dirs = Dir.glob(File.join(voldir, "ch*")).sort
      cbz_path = File.join(dest_dir, "#{title} - Vol. #{volpad}.cbz")
      count = pack_volume(chapter_dirs, cbz_path)
      results << { volume: volpad, path: cbz_path, pages: count }
    end

    results
  end

  def pack_single_volume(tmpdir, dest_dir, title)
    all_dirs = Dir.glob(File.join(tmpdir, "**", "ch*")).sort
    cbz_path = File.join(dest_dir, "#{title} - Vol. 01.cbz")
    count = pack_volume(all_dirs, cbz_path)
    [{ volume: "01", path: cbz_path, pages: count }]
  end
end
