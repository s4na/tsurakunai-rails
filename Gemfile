# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "actionpack", ENV.fetch("ACTIONVIEW_VERSION", ">= 7.1"), "< 9", require: false
gem "actionview", ENV.fetch("ACTIONVIEW_VERSION", ">= 7.1"), "< 9", require: false
gem "activerecord", ENV.fetch("ACTIONVIEW_VERSION", ">= 7.1"), "< 9", require: false
gem "erb_lint", "~> 0.9", require: false

gem "rake", "~> 13.0"
gem "rspec", "~> 3.13"
gem "sqlite3", ENV.fetch("SQLITE_VERSION", "~> 2.0"), require: false

gem "rubocop", ENV.fetch("RUBOCOP_VERSION", ">= 1.72.1")
