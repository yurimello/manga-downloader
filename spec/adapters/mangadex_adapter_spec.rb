require "rails_helper"

RSpec.describe MangadexAdapter do
  let(:http) { instance_double(HttpClientService) }
  let(:adapter) { described_class.new("base_url" => "https://api.mangadex.org") }

  describe "#extract_manga_id" do
    it "extracts ID from MangaDex URL" do
      url = "https://mangadex.org/title/ffc29425-4682-4602-8328-005ed75c5316/a-girl-on-the-shore"
      expect(adapter.extract_manga_id(url)).to eq("ffc29425-4682-4602-8328-005ed75c5316")
    end

    it "returns nil for invalid URL" do
      expect(adapter.extract_manga_id("https://google.com")).to be_nil
    end
  end

  describe "#url_pattern" do
    it "matches MangaDex URLs" do
      expect("https://mangadex.org/title/abc-123/test").to match(adapter.url_pattern)
    end
  end

  describe "#fetch_manga_title" do
    before do
      allow(adapter).to receive(:instance_variable_get).with(:@http).and_return(http)
      adapter.instance_variable_set(:@http, http)
    end

    it "returns English title" do
      allow(http).to receive(:get_json).and_return({
        "data" => {
          "attributes" => {
            "title" => { "en" => "A Girl on the Shore" }
          }
        }
      })

      expect(adapter.fetch_manga_title("abc-123")).to eq("A Girl on the Shore")
    end

    it "falls back to ja-ro title" do
      allow(http).to receive(:get_json).and_return({
        "data" => {
          "attributes" => {
            "title" => { "ja-ro" => "Umibe no Onnanoko" }
          }
        }
      })

      expect(adapter.fetch_manga_title("abc-123")).to eq("Umibe no Onnanoko")
    end
  end

  describe "#fetch_chapters" do
    before { adapter.instance_variable_set(:@http, http) }

    it "paginates and collects chapters" do
      allow(http).to receive(:get_json).and_return({
        "total" => 2,
        "data" => [
          { "id" => "ch1", "attributes" => { "chapter" => "1", "volume" => "1", "translatedLanguage" => "pt-br" } },
          { "id" => "ch2", "attributes" => { "chapter" => "2", "volume" => "1", "translatedLanguage" => "pt-br" } }
        ]
      })

      chapters = adapter.fetch_chapters("abc", languages: ["pt-br"])
      expect(chapters.size).to eq(2)
      expect(chapters.first[:language]).to eq("pt-br")
    end
  end

  describe "#fetch_chapter_images" do
    before { adapter.instance_variable_set(:@http, http) }

    it "returns image data" do
      allow(http).to receive(:get_json).and_return({
        "baseUrl" => "https://cdn.mangadex.network",
        "chapter" => {
          "hash" => "abc123",
          "data" => ["page1.jpg", "page2.jpg"]
        }
      })

      result = adapter.fetch_chapter_images("ch1")
      expect(result[:base_url]).to eq("https://cdn.mangadex.network")
      expect(result[:hash]).to eq("abc123")
      expect(result[:filenames]).to eq(["page1.jpg", "page2.jpg"])
    end
  end

  describe "#image_url" do
    it "constructs full image URL" do
      expect(adapter.image_url("https://cdn.example.com", "abc", "page.jpg"))
        .to eq("https://cdn.example.com/data/abc/page.jpg")
    end
  end
end
