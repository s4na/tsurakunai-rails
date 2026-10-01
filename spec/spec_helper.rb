# frozen_string_literal: true

require "rubocop-tsurakunai-rails"
require "rubocop/rspec/support"

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
  config.order = :random
end
