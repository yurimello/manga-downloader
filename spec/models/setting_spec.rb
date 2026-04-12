require "rails_helper"

RSpec.describe Setting, type: :model do
  describe ".fetch" do
    it "returns default when key does not exist" do
      expect(described_class.fetch(:missing, "fallback")).to eq("fallback")
    end

    it "returns stored value" do
      described_class.store(:test_key, "test_value")
      expect(described_class.fetch(:test_key)).to eq("test_value")
    end
  end

  describe ".store" do
    it "creates a new setting" do
      expect { described_class.store(:new_key, "value") }.to change(described_class, :count).by(1)
    end

    it "updates an existing setting" do
      described_class.store(:key, "old")
      described_class.store(:key, "new")
      expect(described_class.fetch(:key)).to eq("new")
    end
  end
end
