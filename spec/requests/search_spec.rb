require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:adapter) { instance_double(MangadexAdapter) }

  before do
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
  end

  describe "GET /search" do
    it "returns search results as JSON" do
      allow(adapter).to receive(:search_manga).and_return({
        results: [
          { id: "abc-123", title: "Magi", url: "https://mangadex.org/title/abc-123" }
        ],
        total: 1
      })

      get search_path, params: { q: "magi" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["results"].size).to eq(1)
      expect(json["results"].first["title"]).to eq("Magi")
      expect(json["total"]).to eq(1)
    end

    it "passes offset and sort for pagination" do
      allow(adapter).to receive(:search_manga).and_return({ results: [], total: 0 })

      get search_path, params: { q: "magi", offset: 5, sort: "rating" }

      expect(adapter).to have_received(:search_manga).with("magi", limit: 5, offset: 5, sort: "rating")
    end

    it "returns empty for blank query" do
      get search_path, params: { q: "" }

      json = JSON.parse(response.body)
      expect(json["results"]).to be_empty
    end
  end
end
