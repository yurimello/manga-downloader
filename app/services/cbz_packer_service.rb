class CbzPackerService
  def initialize(file_manager:)
    @fs = file_manager
  end

  def pack_volume(source_dirs, output_path)
    @fs.mkdir_p(@fs.dirname(output_path))
    @fs.rm_f(output_path)

    Zip::File.open(output_path, create: true) do |zipfile|
      page_index = 0

      source_dirs.sort.each do |dir|
        next unless @fs.dir_exist?(dir)

        @fs.images_in(dir).each do |file|
          page_index += 1
          ext = @fs.extname(file)
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
      voldir = @fs.join(tmpdir, "vol#{vol}")
      next unless @fs.dir_exist?(voldir)

      chapter_dirs = @fs.glob(@fs.join(voldir, "ch*"))
      cbz_path = @fs.join(dest_dir, "#{title} - Vol. #{volpad}.cbz")
      count = pack_volume(chapter_dirs, cbz_path)
      results << { volume: volpad, path: cbz_path, pages: count }
    end

    results
  end

  def pack_single_volume(tmpdir, dest_dir, title)
    all_dirs = @fs.glob(@fs.join(tmpdir, "**", "ch*"))
    cbz_path = @fs.join(dest_dir, "#{title} - Vol. 01.cbz")
    count = pack_volume(all_dirs, cbz_path)
    [{ volume: "01", path: cbz_path, pages: count }]
  end
end
