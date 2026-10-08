class ListEntrySerializer
  def self.call(entry)
    { id: entry.id, show_id: entry.show_id, status: entry.status, rating: entry.rating }
  end
end
