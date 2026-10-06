# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"
require "json"
require "rbconfig"

root = File.expand_path("..", __dir__)
env = { "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE", File.join(root, "Gemfile")) }
command = ["bundle", "exec", "tsurakunai-rails"]

Dir.mktmpdir("tsurakunai-team-") do |project|
  FileUtils.cp_r("#{root}/spec/fixtures/team_app/.", project)
  stdout, stderr, status = Open3.capture3(env, *command, "init-policy", chdir: project)
  raise "Policy generation failed: #{stdout}\n#{stderr}" unless status.success?

  File.write(File.join(project, ".rubocop.yml"), <<~YAML)
    inherit_from: .rubocop-tsurakunai.yml
    AllCops:
      TargetRubyVersion: 3.0
      TargetRailsVersion: 7.1
      SuggestExtensions: false
      NewCops: enable
      Include: [app/**/*.rb]
    Style:
      Enabled: false
    Layout:
      Enabled: false
    Metrics:
      Enabled: false
    Naming:
      Enabled: false
  YAML
  stdout, stderr, status = Open3.capture3(env, *command, "check", "--", RbConfig.ruby, "verify.rb", chdir: project)
  raise "Team contract failed: #{stdout}\n#{stderr}" unless status.success? && stdout.include?("6 runs, 30 assertions, 0 failures, 0 errors")

  puts "PASS team contracts: explicit CRUD/model/operation; identity, rollback, pending delivery, repeated operation"

  regressions = [
    ["transaction removed", "app/operations/invoices/settle.rb", "Invoice.transaction do", "begin",
     "test_insufficient_credit_rolls_back_the_earlier_transition"],
    ["identity check weakened", "app/models/invoice.rb", "raise Forbidden unless account_id == confirmed_by.id", "raise Forbidden unless confirmed_by.persisted?",
     "test_other_account_cannot_settle"]
  ]
  regressions.each do |name, path, original, replacement, test|
    file = File.join(project, path)
    source = File.read(file)
    raise "Missing team regression target: #{name}" unless source.include?(original)

    File.write(file, source.sub(original, replacement))
    stdout, stderr, status = Open3.capture3(env, *command, "check", "--", RbConfig.ruby, "verify.rb", "--name", test, chdir: project)
    unless status.exitstatus == 1 && stdout.include?("1 failures, 0 errors") && stdout.include?("Ruby lint: PASS")
      raise "Team contract did not detect #{name}: #{stdout}\n#{stderr}"
    end
    puts "PASS team regression: #{name} is lint-clean and fails its real DB contract"
  ensure
    File.write(file, source) if file && source
  end

  policy_cases = {
    "model hook" => ["app/models/hidden.rb", "class Hidden\n  after_save :settle\nend\n", "TsurakunaiRails/ModelCallbacks"],
    "implicit context" => ["app/operations/hidden.rb", "class Hidden\n  def call; Current.account; end\nend\n", "TsurakunaiRails/ImplicitContext"],
    "business mixin" => ["app/models/concerns/hidden.rb", "module Hidden\n  extend ActiveSupport::Concern\nend\n", "TsurakunaiRails/Concern"],
    "action loading" => ["app/controllers/hidden_controller.rb", "class HiddenController\n  before_action :load_invoice\nend\n", "TsurakunaiRails/ControllerCallbacks"]
  }
  policy_cases.each do |name, (path, source, cop)|
    file = File.join(project, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, source)
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rubocop", "--format", "json", "--cache", "false", chdir: project)
    raise "Policy check crashed: #{stderr}" unless status.exitstatus == 1

    offenses = JSON.parse(stdout).fetch("files").flat_map { |entry| entry.fetch("offenses") }
    raise "Policy did not reject #{name}: #{stdout}" unless offenses.map { |offense| offense.fetch("cop_name") } == [cop]

    puts "PASS team policy: rejects #{name} with #{cop}"
  ensure
    File.unlink(file) if file && File.file?(file)
  end
end
