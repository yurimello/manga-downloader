require "rails_helper"

RSpec.describe "Download observable behavior" do
  let(:download) { create(:download) }
  let(:observer) { instance_double(ContextObserver) }

  before do
    allow(observer).to receive(:on_status_changed)
    allow(observer).to receive(:on_progress_updated)
    allow(observer).to receive(:on_log_added)
    download.add_observer(observer)
  end

  describe "status changes" do
    it "notifies on_status_changed when status changes" do
      download.update!(status: :downloading)
      expect(observer).to have_received(:on_status_changed).with(download)
    end

    it "does not notify when status stays the same" do
      download.update!(title: "New Title")
      expect(observer).not_to have_received(:on_status_changed)
    end
  end

  describe "progress changes" do
    it "notifies on_progress_updated when progress changes" do
      download.update!(progress: 50)
      expect(observer).to have_received(:on_progress_updated).with(download)
    end

    it "does not notify when progress stays the same" do
      download.update!(title: "New Title")
      expect(observer).not_to have_received(:on_progress_updated)
    end
  end

  describe "logging" do
    it "notifies on_log_added when log! is called" do
      download.log!("test message", level: :info)
      expect(observer).to have_received(:on_log_added).with(download, "test message", :info)
    end
  end

  describe "multiple observers" do
    let(:second_observer) { instance_double(ContextObserver) }

    before do
      allow(second_observer).to receive(:on_status_changed)
      download.add_observer(second_observer)
    end

    it "notifies all registered observers" do
      download.update!(status: :downloading)
      expect(observer).to have_received(:on_status_changed).with(download)
      expect(second_observer).to have_received(:on_status_changed).with(download)
    end
  end
end
