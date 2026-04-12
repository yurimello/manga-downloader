class HttpClientService
  def initialize(rate_limit_retries: 5, rate_limit_delay: 2)
    @max_retries = rate_limit_retries
    @delay = rate_limit_delay
    @conn = Faraday.new do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end
  end

  def get_json(url, params: {})
    attempt = 0

    loop do
      response = @conn.get(url, params)

      if response.status == 429 || response.body.blank?
        attempt += 1
        raise RateLimitError, "Rate limited after #{@max_retries} retries" if attempt >= @max_retries

        sleep @delay
        next
      end

      parsed = JSON.parse(response.body)

      if parsed.is_a?(Hash) && parsed["result"] == "error"
        attempt += 1
        raise ApiError, "API error after #{@max_retries} retries" if attempt >= @max_retries

        sleep @delay
        next
      end

      return parsed
    end
  end

  def download_file(url, dest_path)
    response = @conn.get(url)
    File.binwrite(dest_path, response.body) if response.status == 200
    response.status == 200
  end

  class RateLimitError < StandardError; end
  class ApiError < StandardError; end
end
