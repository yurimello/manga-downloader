class BaseAdapter
  def extract_manga_id(url)
    raise NotImplementedError
  end

  def fetch_manga_title(manga_id)
    raise NotImplementedError
  end

  def fetch_chapters(manga_id, languages:)
    raise NotImplementedError
  end

  def fetch_chapter_images(chapter_id)
    raise NotImplementedError
  end

  def image_url(base_url, hash, filename)
    raise NotImplementedError
  end

  def search_manga(query, limit: 5, offset: 0, sort: "relevance")
    raise NotImplementedError
  end

  def url_pattern
    raise NotImplementedError
  end
end
