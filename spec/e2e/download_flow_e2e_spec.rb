require "rails_helper"

RSpec.describe "Download E2E", type: :system do
  let(:dest_dir) { Dir.mktmpdir }

  before do
    adapter = instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org})
    AdapterRegistry.instance.register(:mangadex, adapter)
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)

    allow(adapter).to receive(:extract_manga_id).and_return("ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43")
    allow(adapter).to receive(:fetch_manga_title).and_return("Magi")
    allow(adapter).to receive(:image_url) do |base_url, hash, filename|
      "#{base_url}/data/#{hash}/#{filename}"
    end

    Setting.store(:max_concurrent_processes, "1")
    Setting.store(:destination_root, dest_dir)

    # Inline Sidekiq for E2E
    allow(DownloadMangaJob).to receive(:perform_async) do |download_id|
      DownloadMangaJob.new.perform(download_id)
    end
    allow(adapter).to receive(:search_manga).and_return({
      results: [
        { id: "ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43", title: "Magi", url: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43", thumbnail: nil },
        { id: "abc-other", title: "Magic Knight Rayearth", url: "https://mangadex.org/title/abc-other", thumbnail: nil }
      ],
      total: 2
    })

    @adapter = adapter
  end

  after do
    FileUtils.rm_rf(dest_dir)
  end

  def stub_chapters(chapters)
    allow(@adapter).to receive(:fetch_chapters).and_return(chapters)
  end

  def stub_images(filenames: ["page1.jpg", "page2.jpg"])
    allow(@adapter).to receive(:fetch_chapter_images).and_return({
      base_url: "https://cdn.example.com",
      hash: "abc",
      filenames: filenames
    })

    filenames.each do |f|
      stub_request(:get, "https://cdn.example.com/data/abc/#{f}")
        .to_return(status: 200, body: "fake_image_#{f}")
    end
  end

  describe "search selects title and fills URL", :js do
    it "clicking a search result sets title and URL inputs", vcr: { cassette_name: "mangadex/search_magi" } do
      # Use real adapter for search
      AdapterRegistry.instance.register(:mangadex,
        MangadexAdapter.new({ "base_url" => "https://api.mangadex.org" }))

      visit root_path

      # Search input is empty, URL input is empty
      expect(find("[data-manga-search-target='input']").value).to eq("")
      expect(find("[data-manga-search-target='urlInput']").value).to eq("")

      # Type search query
      find("[data-manga-search-target='input']").send_keys("Magi")

      # Wait for dropdown results
      within "[data-manga-search-target='results']" do
        expect(page).to have_css("[data-action='click->manga-search#select']", minimum: 1, wait: 10)
      end

      # Get the first result's title before clicking
      first_result = find("[data-manga-search-target='results'] [data-action='click->manga-search#select']", match: :first)
      expected_title = first_result["data-title"]
      expected_url = first_result["data-url"]

      # Click the result
      first_result.click

      # Title input updated
      expect(find("[data-manga-search-target='input']").value).to eq(expected_title)

      # URL input updated with MangaDex URL
      expect(find("[data-manga-search-target='urlInput']").value).to eq(expected_url)
      expect(expected_url).to match(%r{mangadex\.org/title/})

      # Dropdown hidden
      expect(page).to have_css("[data-manga-search-target='dropdown'].hidden", visible: :all)
    end
  end

  describe "full download flow", :js do
    it "submits URL, downloads, packs CBZ, and shows completed" do
      stub_chapters([
        { id: "ch1", chapter: "1", volume: "1", language: "en" },
        { id: "ch2", chapter: "2", volume: "1", language: "en" }
      ])
      stub_images

      visit root_path

      fill_in "url", with: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi"
      click_button "Process"

      expect(page).to have_css("#completed-downloads", text: "Magi", wait: 10)

      # CBZ file exists on disk
      cbz_path = File.join(dest_dir, "Magi", "Magi - Vol. 01.cbz")
      expect(File.exist?(cbz_path)).to be true
    end
  end

  describe "volume selection", :js do
    it "downloads only selected volumes" do
      stub_chapters([
        { id: "ch1", chapter: "1", volume: "1", language: "en" },
        { id: "ch2", chapter: "2", volume: "1", language: "en" },
        { id: "ch3", chapter: "5", volume: "2", language: "en" },
        { id: "ch4", chapter: "6", volume: "2", language: "en" }
      ])
      stub_images

      visit root_path

      fill_in "url", with: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi"
      fill_in "volumes", with: "2"
      click_button "Process"

      expect(page).to have_css("#completed-downloads", text: "Magi", wait: 10)

      # Only volume 2 CBZ exists
      expect(File.exist?(File.join(dest_dir, "Magi", "Magi - Vol. 02.cbz"))).to be true
      expect(File.exist?(File.join(dest_dir, "Magi", "Magi - Vol. 01.cbz"))).to be false
    end
  end

  describe "reprocess skips downloaded volumes", :js do
    it "skips already downloaded volumes on reprocess" do
      stub_chapters([
        { id: "ch1", chapter: "1", volume: "1", language: "en" },
        { id: "ch2", chapter: "5", volume: "2", language: "en" }
      ])
      stub_images

      visit root_path

      # First download
      fill_in "url", with: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi"
      click_button "Process"

      expect(page).to have_css("#completed-downloads", text: "Magi", wait: 10)

      # Both volumes exist
      vol1 = File.join(dest_dir, "Magi", "Magi - Vol. 01.cbz")
      vol2 = File.join(dest_dir, "Magi", "Magi - Vol. 02.cbz")
      expect(File.exist?(vol1)).to be true
      expect(File.exist?(vol2)).to be true

      # Delete vol2 to prove reprocess doesn't recreate it (it's tracked in DB)
      FileUtils.rm(vol2)

      # Reprocess
      click_button "Reprocess"

      # Should complete quickly — all volumes already downloaded
      expect(page).to have_css("#completed-downloads", text: "Magi", wait: 10)

      # Vol2 should NOT be recreated — it was already tracked as downloaded
      expect(File.exist?(vol2)).to be false
    end
  end

  describe "cancel download", :js do
    it "cancels an active download" do
      stub_chapters([
        { id: "ch1", chapter: "1", volume: "1", language: "en" }
      ])
      stub_images

      # Don't inline the job — let it stay queued
      allow(DownloadMangaJob).to receive(:perform_async)

      visit root_path

      fill_in "url", with: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi"
      click_button "Process"

      expect(page).to have_content("Download queued!")

      visit root_path

      within "#active-downloads" do
        accept_confirm { click_button "Cancel" }
      end

      expect(page).to have_content("Download cancelled.")
      expect(Download.last.reload.status).to eq("cancelled")
    end
  end

  describe "invalid destination", :js do
    it "shows error when destination is not configured" do
      Setting.find_by(key: "destination_root")&.destroy

      stub_chapters([{ id: "ch1", chapter: "1", volume: "1", language: "en" }])
      stub_images

      visit root_path

      fill_in "url", with: "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi"
      click_button "Process"

      expect(page).to have_content("not configured", wait: 5)
    end
  end

  describe "search and select manga", :js do
    it "searches by title, selects result, and fills URL", vcr: { cassette_name: "mangadex/search_magi", record: :new_episodes } do
      stub_chapters([
        { id: "ch1", chapter: "1", volume: "1", language: "en" }
      ])
      stub_images

      # Use real adapter so VCR can intercept the HTTP call
      AdapterRegistry.instance.register(:mangadex,
        MangadexAdapter.new({ "base_url" => "https://api.mangadex.org" }))

      visit root_path

      find("[data-manga-search-target='input']").send_keys("Magi")

      # Dropdown renders with results
      within "[data-manga-search-target='results']" do
        expect(page).to have_text("Magi", wait: 10)
        expect(page).to have_css("[data-action='click->manga-search#select']", minimum: 1)
      end

      # Select first result from dropdown
      within "[data-manga-search-target='results']" do
        first("[data-action='click->manga-search#select']").click
      end

      # Search input shows selected title
      expect(find("[data-manga-search-target='input']").value).not_to be_empty

      # URL input is filled with a MangaDex URL
      url_input = find("[data-manga-search-target='urlInput']")
      expect(url_input.value).to match(%r{mangadex\.org/title/})

      # Dropdown is hidden after selection
      expect(page).to have_css("[data-manga-search-target='dropdown'].hidden", visible: :all)
    end
  end

  describe "settings validation", :js do
    it "shows error when saving invalid destination path" do
      visit edit_settings_path

      fill_in "destination_root", with: "/nonexistent/invalid/path"
      click_button "Save"

      expect(page).to have_content("does not exist or is not writable")
    end

    it "saves valid destination path" do
      new_dir = Dir.mktmpdir

      visit edit_settings_path

      fill_in "destination_root", with: new_dir
      click_button "Save"

      expect(page).to have_content("Settings saved.")
      expect(Setting.fetch(:destination_root)).to eq(new_dir)
    end
  end
end
