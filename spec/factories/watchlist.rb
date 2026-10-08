FactoryBot.define do
  factory :show do
    sequence(:title) { |n| "Show #{n}" }
    kind { "series" }
    genre { "Drama" }
    year { 2020 }
    synopsis { "A show." }
    poster_url { "https://picsum.photos/seed/show/300/450" }
  end

  factory :list_entry do
    show
    status { "want_to_watch" }
  end
end
