require "rails_helper"

RSpec.describe "Settings flow", type: :feature do
  it "updates settings" do
    dir = Dir.mktmpdir
    visit edit_settings_path

    fill_in "max_concurrent_processes", with: "5"
    fill_in "destination_root", with: dir
    click_button "Save"

    expect(page).to have_content("Settings saved.")
    expect(Setting.fetch(:max_concurrent_processes)).to eq("5")
    expect(Setting.fetch(:destination_root)).to eq(dir)
  end

  it "navigates to settings from navbar" do
    visit root_path
    click_link "Settings"
    expect(page).to have_content("Max Concurrent Processes")
  end
end
