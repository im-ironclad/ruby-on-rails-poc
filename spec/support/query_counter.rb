# Counts SQL statements the block runs. Ignores schema lookups and transaction bookkeeping,
# so the number reflects the queries the code under test actually issued.
module QueryCounter
  IGNORED = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i

  def count_queries(&block)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] || payload[:sql].match?(IGNORED)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
