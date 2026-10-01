# frozen_string_literal: true

source "https://rubygems.org"
gemspec

# Older Ruby runs the same consumer checks on Rails 7.1 and its SQLite adapter.
legacy_ruby = Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2")
rails_requirement = legacy_ruby ? "~> 7.1.0" : ">= 7.1"
sqlite_requirement = legacy_ruby ? "~> 1.4" : "~> 2.0"

gem "actionpack", ENV.fetch("ACTIONVIEW_VERSION", rails_requirement), "< 9", require: false
gem "actionview", ENV.fetch("ACTIONVIEW_VERSION", rails_requirement), "< 9", require: false
gem "activerecord", ENV.fetch("ACTIONVIEW_VERSION", rails_requirement), "< 9", require: false
gem "erb_lint", "~> 0.9", require: false

gem "rake", "~> 13.0"
gem "rspec", "~> 3.13"
gem "sqlite3", ENV.fetch("SQLITE_VERSION", sqlite_requirement), require: false

gem "rubocop", ENV.fetch("RUBOCOP_VERSION", ">= 1.72.1")
