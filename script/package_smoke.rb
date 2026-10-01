# frozen_string_literal: true

# Exercises the artifact users install, outside the source bundle.
require "bundler"
require "tmpdir"
require "fileutils"
require "open3"
require "json"
require "rbconfig"

root = File.expand_path("..", __dir__)

def run!(env, *command, directory:)
  stdout, stderr, status = Open3.capture3(env, *command, chdir: directory)
  raise "#{command.join(' ')} failed (#{status.exitstatus}):\n#{stdout}\n#{stderr}" unless status.success?

  stdout
end

Bundler.with_unbundled_env do
  Dir.mktmpdir("tsurakunai-package-") do |workspace|
    gem_home = File.join(workspace, "gems")
    application = File.join(workspace, "app")
    FileUtils.mkdir_p(application)
    artifact = File.join(workspace, "package.gem")
    env = {
      "GEM_HOME" => gem_home,
      "GEM_PATH" => ([gem_home] + Gem.path).join(File::PATH_SEPARATOR),
      "BUNDLE_IGNORE_CONFIG" => "1",
      "BUNDLE_FROZEN" => "false",
      "BUNDLE_GEMFILE" => File.join(application, "Gemfile")
    }
    run!(env, "gem", "build", "rubocop-tsurakunai-rails.gemspec", "--output", artifact, directory: root)
    run!(env, "gem", "install", artifact, "--local", "--ignore-dependencies", "--no-document", directory: application)
    File.write(File.join(application, "Gemfile"), <<~RUBY)
      source "https://rubygems.org"
      gem "rubocop-tsurakunai-rails", "= #{Gem::Specification.load(File.join(root, 'rubocop-tsurakunai-rails.gemspec')).version}"
      gem "erb_lint", "~> 0.9", require: false
      gem "rubocop", "#{ENV.fetch('RUBOCOP_VERSION', '>= 1.72.1')}"
    RUBY
    File.write(File.join(application, ".rubocop.yml"), <<~YAML)
      plugins:
        - rubocop-tsurakunai-rails
      inherit_gem:
        rubocop-tsurakunai-rails: config/rspec.yml
      AllCops:
        DisabledByDefault: true
        SuggestExtensions: false
        TargetRubyVersion: 3.2
        TargetRailsVersion: 7.1
      TsurakunaiRails/ControllerCallbacks:
        Enabled: true
      TsurakunaiRails/DefaultScope:
        Enabled: true
      TsurakunaiRails/ValidationBypass:
        Enabled: true
      TsurakunaiRails/ModelRequestContext:
        Enabled: true
      Rails/EnumHash:
        Enabled: true
    YAML
    run!(env, "bundle", "lock", "--local", directory: application)
    %w[codex claude].each do |target|
      run!(env, "bundle", "exec", "tsurakunai-rails", "install-skill", "--target", target, directory: application)
      folder = target == "codex" ? ".agents" : ".claude"
      installed = File.join(application, folder, "skills", "tsurakunai-rails")
      %w[review.md responsibilities.md views.md].each do |reference|
        raise "Missing installed skill reference: #{reference}" unless File.file?(File.join(installed, "references", reference))
      end
    end
    model_dir = File.join(application, "app", "models")
    FileUtils.mkdir_p(model_dir)
    model = File.join(model_dir, "invoice.rb")
    File.write(model, "class Invoice\n  scope :active, -> { where(active: true) }\nend\n")
    # Executes the public harness with a real RuboCop subprocess and test command.
    test_command = [RbConfig.ruby, "-e", "exit 0"]
    run!(env, "bundle", "exec", "tsurakunai-rails", "check", "--", *test_command, directory: application)
    run!(env, "bundle", "exec", "tsurakunai-rails", "install-view-lint", "--strict-locals", directory: application)
    views = File.join(application, "app", "views", "invoices")
    FileUtils.mkdir_p(views)
    partial = File.join(views, "_invoice.html.erb")
    File.write(partial, "<%# locals: (invoice:) %>\n<%= invoice.number %>\n")
    run!(env, "bundle", "exec", "tsurakunai-rails", "check", "--views", "--", *test_command, directory: application)
    File.write(partial, "<% if @can_edit %><%= @invoice.number %><% end %>\n")
    marker = File.join(application, "tests-ran")
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "tsurakunai-rails", "check", "--views", "--",
                                          RbConfig.ruby, "-e", "File.write(ARGV.fetch(0), 'ran')", marker, chdir: application)
    raise "Installed view harness did not fail: #{stderr}" unless status.exitstatus == 1
    raise "View diagnostics missing: #{stdout}" unless stdout.include?("@can_edit") && stdout.include?("strict locals")
    raise "Tests did not run after view lint failure" unless File.read(marker) == "ran"
    File.write(model, "class Invoice\n  default_scope { where(active: true) }\n  enum :status, [:draft, :paid]\n  def actor; current_user; end\nend\n")
    specs = File.join(application, "spec")
    FileUtils.mkdir_p(specs)
    File.write(File.join(specs, "invoice_spec.rb"), "RSpec.describe Invoice do\n  it { allow_any_instance_of(Invoice).to receive(:total) }\nend\n")
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rubocop", "--format", "json", chdir: application)
    raise "Installed cop did not fail: #{stderr}" unless status.exitstatus == 1

    offenses = JSON.parse(stdout).fetch("files").flat_map { |file| file.fetch("offenses") }
    raise "Installed plugin did not report DefaultScope" unless offenses.any? { |o| o.fetch("cop_name") == "TsurakunaiRails/DefaultScope" }

    %w[TsurakunaiRails/ModelRequestContext Rails/EnumHash RSpec/AnyInstance].each do |cop|
      raise "Installed preset did not report #{cop}" unless offenses.any? { |o| o.fetch("cop_name") == cop }
    end

    puts "Package smoke passed: installed gem, plugin, CLI, view lint, Codex skill, Claude skill."
  end
end
