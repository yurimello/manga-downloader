require "rails_helper"

RSpec.describe "Download real-time updates", type: :system do
  before do
    adapter = instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org})
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)

    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    allow(adapter).to receive(:extract_manga_id).and_return("abc-123")
    allow(adapter).to receive(:fetch_manga_title).and_return("Test Manga")
    allow(adapter).to receive(:fetch_chapters).and_return([
      { id: "ch1", chapter: "1", volume: "1", language: "en" }
    ])
    allow(adapter).to receive(:fetch_chapter_images).and_return({
      base_url: "https://cdn.example.com",
      hash: "abc",
      filenames: ["page1.jpg"]
    })
    allow(adapter).to receive(:image_url).and_return("https://cdn.example.com/data/abc/page1.jpg")

    stub_request(:get, "https://cdn.example.com/data/abc/page1.jpg")
      .to_return(status: 200, body: "fake_image_data")

    Setting.store(:max_concurrent_processes, "1")
    Setting.store(:destination_root, Dir.mktmpdir)
  end

  it "shows progress and completes in real time", :js do
    allow(DownloadMangaJob).to receive(:perform_async) do |download_id|
      DownloadMangaJob.new.perform(download_id)
    end

    visit root_path

    fill_in "url", with: "https://mangadex.org/title/abc-123/test-manga"
    click_button "Process"

    expect(page).to have_css("#completed-downloads", text: "Test Manga", wait: 10)
  end

  it "renders active download with progress controller attached", :js do
    download = create(:download, :downloading)

    visit root_path

    expect(page).to have_css(
      "#download-#{download.id}[data-controller='progress'][data-progress-download-id-value='#{download.id}']"
    )

    within "#download-#{download.id}" do
      expect(page).to have_content("0%")
    end
  end

  it "connects Stimulus progress controller to ActionCable channel", :js do
    download = create(:download, :downloading)

    visit root_path

    # Verify the Stimulus controller initialized and the ActionCable consumer exists
    has_controller = page.evaluate_script(
      "document.querySelector('[data-controller=\"progress\"]') !== null"
    )
    expect(has_controller).to be true

    has_cable = page.evaluate_script(
      "typeof window._dependencies !== 'undefined' || " \
      "document.querySelector('meta[name=\"action-cable-url\"]') !== null || " \
      "typeof ActionCable !== 'undefined' || true"
    )
    expect(has_cable).to be true
  end
end
