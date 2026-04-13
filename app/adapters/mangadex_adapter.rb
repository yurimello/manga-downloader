class MangadexAdapter < BaseAdapter
  def initialize(config = {}, http_client: nil)
    @base_url = config.fetch("base_url", "https://api.mangadex.org")
    @http = http_client || HttpClientService.new(
      rate_limit_retries: config.fetch("rate_limit_retries", 5),
      rate_limit_delay: config.fetch("rate_limit_delay", 2)
    )
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
