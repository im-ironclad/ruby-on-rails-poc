class ListEntry < ApplicationRecord
  belongs_to :show

  enum :status, { want_to_watch: "want_to_watch", watching: "watching", watched: "watched" }, validate: true

  validates :show_id, uniqueness: true
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
end
