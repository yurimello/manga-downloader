require "rails_helper"

RSpec.describe ValidateDestinationCommand do
  describe ".call" do
    it "passes when destination is configured and writable" do
      Dir.mktmpdir do |dir|
        Setting.store(:destination_root, dir)
        result = described_class.call

        expect(result).to be_success
      end
    end

    it "fails when destination is not configured" do
      result = described_class.call

      expect(result).to be_failure
      expect(result.message).to include("not configured")
    end

    it "fails when destination does not exist" do
      Setting.store(:destination_root, "/nonexistent/path")
      result = described_class.call

      expect(result).to be_failure
      expect(result.message).to include("does not exist or is not writable")
    end
  end
end
