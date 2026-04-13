require "rails_helper"

RSpec.describe "Download E2E", type: :system do
  let(:dest_dir) { Dir.mktmpdir }
  let(:manga_url) { "https://mangadex.org/title/ce63e6b8-fad8-48bc-a2aa-d801fb8d5d43/magi" }

  before do
    Setting.store(:max_concurrent_processes, "1")
    Setting.store(:destination_root, dest_dir)
  end

  after do
    FileUtils.rm_rf(dest_dir)
  end

  describe "search selects title and fills URL", :js do
    it "clicking a search result sets title and URL inputs", vcr: { cassette_name: "e2e/search_magi", record: :new_episodes } do
      visit root_path

      # Stimulus controller is connected
      expect(page).to have_css("[data-controller='manga-search']")

      # Controller has all required targets
      controller_el = find("[data-controller='manga-search']")
      expect(controller_el).to have_css("[data-manga-search-target='input']")
      expect(controller_el).to have_css("[data-manga-search-target='urlInput']")
      expect(controller_el).to have_css("[data-manga-search-target='dropdown']", visible: :all)
      expect(controller_el).to have_css("[data-manga-search-target='results']", visible: :all)

      # Verify Stimulus controller is initialized
      is_connected = page.evaluate_script(<<~JS)
        (function() {
          var el = document.querySelector("[data-controller='manga-search']");
          return el && el.dataset.controller === 'manga-search';
        })()
      JS
      expect(is_connected).to be true

      # Inputs start empty
      search_input = find("[data-manga-search-target='input']")
      url_input = find("[data-manga-search-target='urlInput']")
      expect(search_input.value).to eq("")
      expect(url_input.value).to eq("")

      # Dropdown starts hidden
      expect(page).to have_css("[data-manga-search-target='dropdown'].hidden", visible: :all)

      # Type search query — triggers keyup -> manga-search#search
      search_input.send_keys("Magi")
      expect(search_input.value).to eq("Magi")

      # Dropdown becomes visible with results
      expect(page).not_to have_css("[data-manga-search-target='dropdown'].hidden", wait: 10)

      within "[data-manga-search-target='results']" do
        expect(page).to have_css("[data-action='click->manga-search#select']", minimum: 1)
      end

      # Each result has data-title and data-url attributes
      first_result = find("[data-manga-search-target='results'] [data-action='click->manga-search#select']", match: :first)
      expect(first_result["data-title"]).not_to be_nil
      expect(first_result["data-url"]).not_to be_nil
      expect(first_result["data-url"]).to match(%r{mangadex\.org/title/})

      expected_title = first_result["data-title"]
      expected_url = first_result["data-url"]

      # Click the result
      first_result.click

      # Search input updated with selected title
      expect(search_input.value).to eq(expected_title)

      # URL input updated with MangaDex URL
      expect(url_input.value).to eq(expected_url)

      # Dropdown hidden after selection
      expect(page).to have_css("[data-manga-search-target='dropdown'].hidden", visible: :all)

      # URL input is submittable (has value in the form)
      expect(find("input[name='url']").value).to eq(expected_url)
    end
  end

  describe "full download flow", :js do
    before do
      Sidekiq.default_configuration.test_mode = :inline
      stub_request(:get, %r{\.mangadex\.network/data/})
        .to_return(status: 200, body: "\xFF\xD8\xFF\xE0fake_image_data")
    end

    after { Sidekiq.default_configuration.test_mode = :fake }

    it "submits URL, downloads, packs CBZ, and shows completed", vcr: { cassette_name: "e2e/download_magi_vol1", record: :new_episodes } do
      visit root_path

      fill_in "url", with: manga_url
      fill_in "volumes", with: "1"
      click_button "Process"

      expect(page).to have_css("#completed-downloads", text: "Magi", wait: 30)

      cbz_files = Dir.glob(File.join(dest_dir, "**", "*.cbz"))
      expect(cbz_files).not_to be_empty
    end
  end

  describe "cancel download", :js do
    it "cancels an active download" do
      Sidekiq.default_configuration.test_mode = :fake

      visit root_path

      fill_in "url", with: manga_url
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

      visit root_path

      fill_in "url", with: manga_url
      click_button "Process"

      expect(page).to have_content("not configured", wait: 5)
    end
  end

  describe "search and select manga", :js do
    it "searches by title, selects result, and fills URL", vcr: { cassette_name: "e2e/search_magi", record: :new_episodes } do
      visit root_path

      find("[data-manga-search-target='input']").send_keys("Magi")

      within "[data-manga-search-target='results']" do
        expect(page).to have_text("Magi", wait: 10)
        expect(page).to have_css("[data-action='click->manga-search#select']", minimum: 1)
      end

      within "[data-manga-search-target='results']" do
        first("[data-action='click->manga-search#select']").click
      end

      expect(find("[data-manga-search-target='input']").value).not_to be_empty
      url_input = find("[data-manga-search-target='urlInput']")
      expect(url_input.value).to match(%r{mangadex\.org/title/})
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
