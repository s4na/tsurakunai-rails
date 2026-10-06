# frozen_string_literal: true

require_relative "lib/tsurakunai/rails/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-tsurakunai-rails"
  spec.version = Tsurakunai::Rails::VERSION
  spec.authors = ["s4na"]
  spec.summary = "Focused Rails guardrails for humans and coding agents"
  spec.description = "Team conventions for explicit Rails flow, with RuboCop checks and portable implementation/review skills."
  spec.homepage = "https://github.com/s4na/tsurakunai-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "default_lint_roller_plugin" => "RuboCop::TsurakunaiRails::Plugin",
    "rubygems_mfa_required" => "true"
  }
  spec.files = Dir["lib/**/*.rb", "exe/*", "config/*.{yml,md}", "skills/**/*", "README.md", "LICENSE", "docs/*.md"]
  spec.bindir = "exe"
  spec.executables = ["tsurakunai-rails"]
  spec.require_paths = ["lib"]
  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", ">= 1.74.0", "< 2.0"
  spec.add_dependency "rubocop-rails", ">= 2.30", "< 3.0"
  spec.add_dependency "rubocop-rspec", ">= 3.4", "< 4.0"
end
