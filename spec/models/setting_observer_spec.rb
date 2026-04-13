require "rails_helper"

RSpec.describe "Setting observable behavior" do
  let(:observer) { instance_double(ContextObserver) }

  before do
    allow(observer).to receive(:on_error)
  end

  describe "validation errors" do
    it "notifies on_error when destination_root is not writable" do
      setting = Setting.find_or_initialize_by(key: "destination_root")
      setting.value = "/nonexistent/path"
      setting.add_observer(observer)
      setting.save

      expect(observer).to have_received(:on_error).with(setting, array_including("Value directory '/nonexistent/path' does not exist or is not writable"))
    end

    it "does not notify when validation passes" do
      Dir.mktmpdir do |dir|
        setting = Setting.find_or_initialize_by(key: "destination_root")
        setting.value = dir
        setting.add_observer(observer)
        setting.save!

        expect(observer).not_to have_received(:on_error)
      end
    end
  end

  describe "store with observers" do
    it "passes observers to the setting" do
      expect {
        Setting.store("destination_root", "/nonexistent/path", observers: [observer])
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(observer).to have_received(:on_error)
    end
  end
end
