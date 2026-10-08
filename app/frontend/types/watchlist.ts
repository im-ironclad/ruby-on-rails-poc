// Mirrors app/serializers/show_serializer.rb and list_entry_serializer.rb.

export type ShowKind = 'movie' | 'series'

export type ListStatus = 'want_to_watch' | 'watching' | 'watched'

export type Rating = 1 | 2 | 3 | 4 | 5

export interface ListEntry {
  id: number
  show_id: number
  status: ListStatus
  rating: Rating | null
}

export interface Show {
  id: number
  title: string
  kind: ShowKind
  genre: string
  year: number
  synopsis: string
  poster_url: string
  list_entry: ListEntry | null
}
