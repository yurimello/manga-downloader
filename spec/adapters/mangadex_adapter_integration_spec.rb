require "rails_helper"

RSpec.describe MangadexAdapter, "integration", type: :adapter do
  let(:adapter) { described_class.new("base_url" => "https://api.mangadex.org") }

  describe "#fetch_manga_title", vcr: { cassette_name: "mangadex/fetch_title" } do
    it "fetches title from MangaDex API" do
      title = adapter.fetch_manga_title("ffc29425-4682-4602-8328-005ed75c5316")
      expect(title).to eq("A Girl on the Shore")
    end
  end

  describe "#fetch_chapters", vcr: { cassette_name: "mangadex/fetch_chapters_ptbr" } do
    it "fetches pt-br chapters" do
      chapters = adapter.fetch_chapters("ffc29425-4682-4602-8328-005ed75c5316", languages: ["pt-br"])
      expect(chapters).not_to be_empty
      expect(chapters.first[:language]).to eq("pt-br")
      expect(chapters.first[:chapter]).to be_present
    end
  end

  describe "#fetch_chapter_images", vcr: { cassette_name: "mangadex/fetch_images" } do
    it "fetches image data for a chapter" do
      result = adapter.fetch_chapter_images("bfa473d4-64d8-4ecb-8577-5a443c6e8849")
      expect(result[:base_url]).to be_present
      expect(result[:hash]).to be_present
      expect(result[:filenames]).to be_an(Array)
      expect(result[:filenames]).not_to be_empty
    end
  end
end
