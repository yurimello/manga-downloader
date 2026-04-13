class MangadexAdapter < BaseAdapter
  def initialize(config = {}, http_client: HttpClientService.new)
    @base_url = config.fetch("base_url", "https://api.mangadex.org")
    @http = http_client
  end

  def search_manga(query, limit: 5, offset: 0, sort: "relevance", languages: nil)
    languages ||= LanguageConfig.codes

    params = {
      "title" => query,
      "limit" => limit,
      "offset" => offset,
      "includes[]" => "cover_art",
      "order[#{sort}]" => "desc",
      "availableTranslatedLanguage[]" => languages
    }

    data = @http.get_json("#{@base_url}/manga", params: params)

    results = (data["data"] || []).map do |manga|
      titles = manga.dig("attributes", "title") || {}
      title = titles["en"] || titles["ja-ro"] || titles["ja"] || "Unknown"
      cover = (manga["relationships"] || []).find { |r| r["type"] == "cover_art" }
      cover_filename = cover&.dig("attributes", "fileName")
      thumbnail = cover_filename ? "https://uploads.mangadex.org/covers/#{manga["id"]}/#{cover_filename}.256.jpg" : nil
      {
        id: manga["id"],
        title: title,
        url: "https://mangadex.org/title/#{manga["id"]}",
        thumbnail: thumbnail
      }
    end

    { results: results, total: data["total"] || 0 }
  end

  def url_pattern
    %r{mangadex\.org/title/([a-f0-9-]+)}
  end

  def extract_manga_id(url)
    match = url.match(url_pattern)
    match[1] if match
  end

  def fetch_manga_title(manga_id)
    data = @http.get_json("#{@base_url}/manga/#{manga_id}")
    titles = data.dig("data", "attributes", "title") || {}
    titles["en"] || titles["ja-ro"] || titles["ja"] || "Unknown"
  end

  def fetch_chapters(manga_id, languages:)
    all_chapters = []

    languages.each do |lang|
      offset = 0
      loop do
        data = @http.get_json(
          "#{@base_url}/manga/#{manga_id}/feed",
          params: {
            "translatedLanguage[]" => lang,
            "limit" => 100,
            "offset" => offset,
            "order[chapter]" => "asc"
          }
        )

        total = data["total"] || 0
        break if total == 0 && offset == 0

        (data["data"] || []).each do |ch|
          attrs = ch["attributes"]
          all_chapters << {
            id: ch["id"],
            chapter: attrs["chapter"] || "0",
            volume: attrs["volume"] || "0",
            language: attrs["translatedLanguage"]
          }
        end

        offset += 100
        break if offset >= total
      end
    end

    all_chapters
  end

  def fetch_chapter_images(chapter_id)
    data = @http.get_json("#{@base_url}/at-home/server/#{chapter_id}")
    {
      base_url: data["baseUrl"],
      hash: data.dig("chapter", "hash"),
      filenames: data.dig("chapter", "data") || []
    }
  end

  def image_url(base_url, hash, filename)
    "#{base_url}/data/#{hash}/#{filename}"
  end
end
