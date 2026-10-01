# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubygems/package_task"

RSpec::Core::RakeTask.new(:spec)
Gem::PackageTask.new(Gem::Specification.load("rubocop-tsurakunai-rails.gemspec")).define
desc "Build the distributable gem in pkg/"
task build: :gem
task default: :spec
