ENV["RAILS_ENV"] ||= "test"

# Only generates the report; the coverage gate is script/check_coverage.rb, because
# SimpleCov's inline minimum_coverage can't propagate a non-zero exit through `bin/rails test`.
if ENV["COVERAGE"] == "1"
  require "simplecov"
  SimpleCov.start "rails" do
    command_name ENV.fetch("SIMPLECOV_COMMAND_NAME", "rails-tests")
  end
end

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# Every digest path (fixtures, has_secure_password, recovery codes) falls back to
# BCrypt::Engine.cost; at the default cost hashing dominates suite runtime.
require "bcrypt"
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

module ActiveSupport
  class TestCase
    # Serial under coverage so SimpleCov's resultset isn't fragmented across forked workers.
    parallelize(workers: ENV["COVERAGE"] == "1" ? 1 : :number_of_processors)

    fixtures :all
  end
end
