require "rails_helper"

RSpec.describe "Download flow", type: :feature do
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  before do
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
    allow(DownloadMangaJob).to receive(:perform_async)
  end

  it "submits a download from home page" do
    visit root_path

    fill_in "url", with: "https://mangadex.org/title/abc-123/test-manga"
    click_button "Process"

    expect(page).to have_content("Download queued!")
    expect(Download.count).to eq(1)
    expect(Download.first.url).to include("abc-123")
  end

  it "submits with volumes" do
    visit root_path

    fill_in "url", with: "https://mangadex.org/title/abc-123/test-manga"
    fill_in "volumes", with: "1, 2, 3"
    click_button "Process"

    expect(Download.first.volumes).to eq("1, 2, 3")
  end

  it "shows active downloads" do
    create(:download, :downloading)
    visit root_path

    within "#active-downloads" do
      expect(page).to have_content("A Girl on the Shore")
    end
  end

  it "shows completed downloads with status icon" do
    create(:download, :completed, title: "Completed Manga")
    create(:download, :failed, title: "Failed Manga")
    visit root_path

    within "#completed-downloads" do
      expect(page).to have_content("Completed Manga")
      expect(page).to have_content("Failed Manga")
    end
  end

  it "cancels an active download" do
    download = create(:download, :downloading)
    visit root_path

    click_button "Cancel"

    expect(download.reload.status).to eq("cancelled")
  end
end
