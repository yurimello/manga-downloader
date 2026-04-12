require "rails_helper"

RSpec.describe "Settings", type: :request do
  describe "GET /settings/edit" do
    it "renders the settings page" do
      get edit_settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Max Concurrent Processes")
      expect(response.body).to include("Destination Root")
    end
  end

  describe "PATCH /settings" do
    it "updates settings" do
      patch settings_path, params: {
        max_concurrent_processes: "3",
        destination_root: "/tmp/manga"
      }
      expect(response).to redirect_to(edit_settings_path)
      expect(Setting.fetch(:max_concurrent_processes)).to eq("3")
      expect(Setting.fetch(:destination_root)).to eq("/tmp/manga")
    end
  end
end
