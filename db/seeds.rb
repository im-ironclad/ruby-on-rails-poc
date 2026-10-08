# Idempotent: safe to run more than once. Issuers and shows are matched by natural key,
# bonds by CUSIP. Payment history is relative to today so the dashboard always has data.

issuers = [
  { name: "City of Portland", issuer_type: "city", state: "OR" },
  { name: "Multnomah County", issuer_type: "county", state: "OR" },
  { name: "Austin Independent School District", issuer_type: "school_district", state: "TX" },
  { name: "Denver Water", issuer_type: "utility", state: "CO" }
].to_h do |attrs|
  [attrs[:name], Issuer.find_or_create_by!(name: attrs[:name], state: attrs[:state]) { |i| i.issuer_type = attrs[:issuer_type] }]
end

today = Date.current
bonds = [
  ["City of Portland", "General Obligation Bonds, Series 2019A", "736688AA1", 25_000_000_00, "0.0400", today.prev_year(6) + 20, 15],
  ["City of Portland", "Sewer System Revenue Bonds, Series 2022B", "736688BB2", 12_500_000_00, "0.0450", today.prev_year(3) + 45, 10],
  ["Multnomah County", "Full Faith and Credit Obligations, Series 2021", "625517CC3", 40_000_000_00, "0.0325", today.prev_year(4) + 60, 20],
  ["Austin Independent School District", "Unlimited Tax School Building Bonds, Series 2020", "052430DD4", 60_000_000_00, "0.0375", today.prev_year(5) + 10, 25],
  ["Austin Independent School District", "Refunding Bonds, Series 2023", "052430EE5", 8_000_000_00, "0.0500", today.prev_year(2) - 15, 8],
  ["Denver Water", "Water Revenue Bonds, Series 2018", "249182FF6", 30_000_000_00, "0.0410", today.prev_year(7) + 80, 20]
]

bonds.each do |issuer_name, series, cusip, par, rate, issued_on, years|
  next if Bond.exists?(cusip:)

  bond = Bonds::Create.call(
    issuer_id: issuers.fetch(issuer_name).id, series_name: series, cusip:,
    par_amount_cents: par, coupon_rate: rate, issued_on:, maturity_on: issued_on.next_year(years)
  )
  # History: everything past due was paid on time, except one Austin payment left overdue for the demo.
  bond.debt_service_payments.where(due_on: ...today).find_each do |payment|
    payment.update!(paid_on: payment.due_on) unless cusip == "052430EE5" && payment.due_on > today - 30
  end
end

shows = [
  ["Severance", "series", "Thriller", 2022, "Office workers have their memories surgically split between work and home."],
  ["The Bear", "series", "Drama", 2022, "A fine-dining chef returns to Chicago to run his family's sandwich shop."],
  ["Andor", "series", "Sci-Fi", 2022, "A thief becomes a rebel in the years before the Battle of Yavin."],
  ["Slow Horses", "series", "Thriller", 2022, "Disgraced MI5 agents work out of a dumping-ground office."],
  ["Shogun", "series", "Drama", 2024, "An English navigator is caught in the power struggles of feudal Japan."],
  ["Arcane", "series", "Animation", 2021, "Two sisters end up on opposite sides of a war between rival cities."],
  ["Succession", "series", "Drama", 2018, "The children of a media mogul fight over who will take control."],
  ["The Office", "series", "Comedy", 2005, "A mockumentary about the employees of a paper company."],
  ["Dune: Part Two", "movie", "Sci-Fi", 2024, "Paul Atreides unites with the Fremen to wage war on House Harkonnen."],
  ["Everything Everywhere All at Once", "movie", "Comedy", 2022, "A laundromat owner discovers she can access other universes."],
  ["Oppenheimer", "movie", "Drama", 2023, "The story of the physicist who led the Manhattan Project."],
  ["Spider-Man: Across the Spider-Verse", "movie", "Animation", 2023, "Miles Morales meets a society of Spider-People."],
  ["Past Lives", "movie", "Romance", 2023, "Childhood friends reconnect two decades after one emigrates."],
  ["Knives Out", "movie", "Mystery", 2019, "A detective investigates the death of a crime novelist."],
  ["Parasite", "movie", "Thriller", 2019, "A poor family schemes its way into a wealthy household."]
]

shows.each do |title, kind, genre, year, synopsis|
  Show.find_or_create_by!(title:, year:) do |show|
    show.kind = kind
    show.genre = genre
    show.synopsis = synopsis
    show.poster_url = "https://picsum.photos/seed/#{title.parameterize}/300/450"
  end
end

ListEntry.find_or_create_by!(show: Show.find_by!(title: "Severance")) { |e| e.status = "watching" }
ListEntry.find_or_create_by!(show: Show.find_by!(title: "Parasite")) { |e| e.assign_attributes(status: "watched", rating: 5) }

puts "Seeded #{Issuer.count} issuers, #{Bond.count} bonds, #{DebtServicePayment.count} payments, #{Show.count} shows."
