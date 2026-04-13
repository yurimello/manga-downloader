require "rails_helper"

RSpec.describe ChapterSelectorService do
  let(:priorities) do
    { "pt-br" => 1, "es-la" => 2, "en" => 4 }
  end
  let(:service) { described_class.new(priorities: priorities) }

  describe "#select" do
    let(:chapters) do
      [
        { id: "a", chapter: "1", volume: "1", language: "en" },
        { id: "b", chapter: "1", volume: "1", language: "pt-br" },
        { id: "c", chapter: "2", volume: "1", language: "en" },
        { id: "d", chapter: "3", volume: "1", language: "es-la" }
      ]
    end

    it "picks best language per chapter" do
      result = service.select(chapters)
      expect(result.size).to eq(3)
      expect(result.find { |c| c[:chapter] == "1" }[:id]).to eq("b") # pt-br wins
      expect(result.find { |c| c[:chapter] == "2" }[:id]).to eq("c") # en only
      expect(result.find { |c| c[:chapter] == "3" }[:id]).to eq("d") # es-la only
    end

    it "filters by volumes" do
      chapters_with_vols = [
        { id: "a", chapter: "1", volume: "1", language: "en" },
        { id: "b", chapter: "5", volume: "2", language: "en" }
      ]

      result = service.select(chapters_with_vols, volumes: ["1"])
      expect(result.size).to eq(1)
      expect(result.first[:chapter]).to eq("1")
    end

    it "returns all when volumes is nil" do
      result = service.select(chapters, volumes: nil)
      expect(result.size).to eq(3)
    end
  end

  describe "#language_summary" do
    it "counts chapters per language" do
      chapters = [
        { language: "pt-br" },
        { language: "pt-br" },
        { language: "en" }
      ]
      expect(service.language_summary(chapters)).to eq({ "pt-br" => 2, "en" => 1 })
    end
  end
end
