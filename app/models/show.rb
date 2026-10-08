class Show < ApplicationRecord
  has_one :list_entry, dependent: :destroy

  enum :kind, { movie: "movie", series: "series" }, validate: true

  validates :title, :genre, :poster_url, presence: true
  validates :title, uniqueness: { scope: :year }
  validates :year, numericality: { only_integer: true, greater_than: 1880 }
end
