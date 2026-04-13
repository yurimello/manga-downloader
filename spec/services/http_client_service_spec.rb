require "rails_helper"

RSpec.describe HttpClientService do
  let(:service) { described_class.new(rate_limit_retries: 3, rate_limit_delay: 0) }

  describe "#get_json" do
    it "returns parsed JSON on success" do
      stub_request(:get, "https://api.example.com/test")
        .to_return(status: 200, body: '{"result": "ok"}')

      result = service.get_json("https://api.example.com/test")
      expect(result).to eq({ "result" => "ok" })
    end

    it "retries on 429" do
      stub_request(:get, "https://api.example.com/test")
        .to_return(status: 429, body: "")
        .then.to_return(status: 200, body: '{"result": "ok"}')

      result = service.get_json("https://api.example.com/test")
      expect(result).to eq({ "result" => "ok" })
    end

    it "raises after max retries" do
      stub_request(:get, "https://api.example.com/test")
        .to_return(status: 429, body: "")

      expect { service.get_json("https://api.example.com/test") }
        .to raise_error(HttpClientService::RateLimitError)
    end

    it "retries on API error response" do
      stub_request(:get, "https://api.example.com/test")
        .to_return(status: 200, body: '{"result": "error"}')
        .then.to_return(status: 200, body: '{"result": "ok"}')

      result = service.get_json("https://api.example.com/test")
      expect(result).to eq({ "result" => "ok" })
    end
  end

end
