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
    it "updates settings with valid destination" do
      dir = Dir.mktmpdir
      patch settings_path, params: {
        max_concurrent_processes: "3",
        destination_root: dir
      }
      expect(response).to redirect_to(edit_settings_path)
      expect(Setting.fetch(:max_concurrent_processes)).to eq("3")
      expect(Setting.fetch(:destination_root)).to eq(dir)
    end

    it "redirects with error for invalid destination" do
      patch settings_path, params: {
        max_concurrent_processes: "3",
        destination_root: "/nonexistent/path"
      }
      expect(response).to redirect_to(edit_settings_path)
      expect(flash[:alert]).to include("does not exist or is not writable")
    end
  end
end
