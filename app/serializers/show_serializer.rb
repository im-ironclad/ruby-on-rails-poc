# Mirrors app/frontend/types/watchlist.ts (Show, ListEntry).
class ShowSerializer
  # Expects list_entry preloaded (see Api::ShowsController#index).
  def self.call(show)
    {
      id: show.id,
      title: show.title,
      kind: show.kind,
      genre: show.genre,
      year: show.year,
      synopsis: show.synopsis,
      poster_url: show.poster_url,
      list_entry: show.list_entry && ListEntrySerializer.call(show.list_entry)
    }
  end
end
