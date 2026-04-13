require "rails_helper"

RSpec.describe "Downloads", type: :request do
  let(:adapter) { instance_double(MangadexAdapter, url_pattern: %r{mangadex\.org}) }

  before do
    Setting.store(:destination_root, Dir.mktmpdir)
    allow(AdapterRegistry).to receive(:for_url).and_return(adapter)
    registry = AdapterRegistry.instance
    registry.register(:mangadex, adapter)
    allow(DownloadMangaJob).to receive(:perform_async)
  end

  describe "GET /" do
    it "renders the index page" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New Download")
    end

    it "shows active downloads" do
      create(:download, :downloading)
      get root_path
      expect(response.body).to include("A Girl on the Shore")
    end

    it "shows completed downloads" do
      create(:download, :completed)
      get root_path
      expect(response.body).to include("A Girl on the Shore")
    end
  end

  describe "POST /downloads" do
    it "creates a download and redirects" do
      post downloads_path, params: { url: "https://mangadex.org/title/abc-123/test" }
      expect(response).to redirect_to(root_path)
      expect(Download.count).to eq(1)
      expect(Download.first.status).to eq("queued")
    end

    it "passes volumes" do
      post downloads_path, params: { url: "https://mangadex.org/title/abc-123/test", volumes: "1, 2" }
      expect(Download.first.volumes).to eq("1, 2")
    end

    it "shows error for invalid URL" do
      allow(AdapterRegistry).to receive(:for_url).and_return(nil)
      post downloads_path, params: { url: "https://bad.com" }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /downloads/:id" do
    it "cancels an active download" do
      download = create(:download, :downloading)
      delete download_path(download)
      expect(download.reload.status).to eq("cancelled")
    end

    it "destroys a completed download" do
      download = create(:download, :completed)
      delete download_path(download)
      expect(Download.exists?(download.id)).to be false
    end
  end
end
