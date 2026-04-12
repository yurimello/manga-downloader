require "rails_helper"

RSpec.describe AdapterRegistry do
  let(:registry) { described_class.new }
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  describe "#register" do
    it "registers an adapter by name" do
      registry.register(:mangadex, adapter)
      expect(registry.for_source(:mangadex)).to eq(adapter)
    end
  end

  describe "#for_url" do
    before { registry.register(:mangadex, adapter) }

    it "returns adapter matching URL" do
      expect(registry.for_url("https://mangadex.org/title/abc-123/test")).to eq(adapter)
    end

    it "returns nil for unknown URL" do
      expect(registry.for_url("https://unknown.com/manga/test")).to be_nil
    end
  end

  describe "#sources" do
    it "lists registered source names" do
      registry.register(:mangadex, adapter)
      expect(registry.sources).to eq(["mangadex"])
    end
  end
end
