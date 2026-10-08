require "rails_helper"

RSpec.describe "Watchlist API", type: :request do
  describe "GET /api/shows" do
    it "returns every show with its list entry, or null when not on the list" do
      on_list = create(:show, title: "Andor")
      create(:list_entry, show: on_list, status: "watching", rating: 5)
      create(:show, title: "Barry")

      get "/api/shows"

      expect(response.parsed_body.map { |s| [s["title"], s["list_entry"]&.slice("status", "rating")] }).to eq([
        ["Andor", { "status" => "watching", "rating" => 5 }],
        ["Barry", nil]
      ])
    end

    it "preloads list entries instead of querying per show" do
      create(:list_entry)
      one = count_queries { get "/api/shows" }
      3.times { create(:list_entry) }
      four = count_queries { get "/api/shows" }

      expect(four).to eq(one)
    end
  end

  describe "list entry lifecycle" do
    let(:show) { create(:show) }

    it "adds, updates status and rating, then removes" do
      post "/api/list_entries", params: { list_entry: { show_id: show.id } }, as: :json
      expect(response).to have_http_status(:created)
      entry_id = response.parsed_body["id"]
      expect(response.parsed_body).to include("status" => "want_to_watch", "rating" => nil)

      patch "/api/list_entries/#{entry_id}", params: { list_entry: { status: "watched", rating: 4 } }, as: :json
      expect(response.parsed_body).to include("status" => "watched", "rating" => 4)

      delete "/api/list_entries/#{entry_id}"
      expect(response).to have_http_status(:no_content)
      expect(ListEntry.exists?(entry_id)).to be(false)
    end

    it "rejects adding the same show twice" do
      create(:list_entry, show:)

      post "/api/list_entries", params: { list_entry: { show_id: show.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("show_id" => ["has already been taken"])
    end

    it "rejects a rating outside 1 to 5 and an unknown status" do
      entry = create(:list_entry, show:)

      patch "/api/list_entries/#{entry.id}", params: { list_entry: { rating: 9, status: "binged" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("rating" => ["must be in 1..5"], "status" => ["is not included in the list"])
    end
  end
end
