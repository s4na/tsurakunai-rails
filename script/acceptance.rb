# frozen_string_literal: true

# Execute real Rails behavior, then prove each regression is caught by its contract.
require "tmpdir"
require "fileutils"
require "open3"
require "json"
require "rbconfig"

root = File.expand_path("..", __dir__)
fixture = File.join(root, "spec/fixtures/acceptance_app")
cases = [
  ["tenant", "app/controllers/invoices_controller.rb",
   "current_account.invoices.find(params[:id])", "Invoice.find(params[:id])",
   "test_other_tenant_is_not_readable_or_writable", []],
  ["failed_form", "app/controllers/invoices_controller.rb",
   "render :edit, status: 422", "@invoice.reload\n      render :edit, status: 422",
   "test_validation_failure_preserves_input_errors_and_database", []],
  ["model_validation", "app/models/invoice.rb",
   "validates :amount_cents, numericality: { greater_than: 0 }", "# validation removed",
   "test_validation_failure_preserves_input_errors_and_database", []],
  ["commit_hook", "app/models/invoice.rb",
   "after_save_commit :record_notification", "after_create_commit :record_notification\n  after_update_commit :record_notification",
   "test_model_operation_works_without_a_request_and_notifies_on_both_events", ["Rails/AfterCommitOverride"]],
  ["partial_object", "app/views/invoices/_invoice.html.erb",
   "invoice.memo", "@invoice.memo",
   "test_collection_renders_each_object_without_leaking_other_tenants_or_mutating_data", []],
  ["permitted_input", "app/controllers/invoices_controller.rb",
   "permit(:memo, :amount_cents)", "permit(:memo, :amount_cents, :account_id)",
   "test_success_saves_only_permitted_values_and_notifies_after_commit", []]
].freeze

env = { "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE", File.join(root, "Gemfile")) }
command = ["bundle", "exec", "tsurakunai-rails"]

Dir.mktmpdir("tsurakunai-acceptance-") do |project|
  FileUtils.cp_r("#{fixture}/.", project)
  File.write(File.join(project, ".rubocop.yml"), <<~YAML)
    plugins:
      - rubocop-tsurakunai-rails
    AllCops:
      NewCops: enable
      SuggestExtensions: false
      TargetRubyVersion: 3.0
      TargetRailsVersion: 7.1
      Include:
        - app/**/*.rb
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
  raise "Healthy consumer failed:\n#{stdout}\n#{stderr}" unless status.success? && stdout.include?("6 runs, 40 assertions, 0 failures, 0 errors")

  puts "PASS healthy: public check + real Rack requests / SQLite / Action View (6 contracts, 40 assertions)"
  stdout, stderr, status = Open3.capture3(env, *command, "install-view-lint", chdir: project)
  raise "View profile installation failed:\n#{stdout}\n#{stderr}" unless status.success?

  stdout, stderr, status = Open3.capture3(env, *command, "check", "--views", "--", RbConfig.ruby, "verify.rb", chdir: project)
  raise "Healthy view consumer failed:\n#{stdout}\n#{stderr}" unless status.success?

  puts "PASS optional views: explicit profile accepts the healthy templates"
  cases.each do |name, path, original, regression, test, expected_cops|
    file = File.join(project, path)
    source = File.read(file)
    raise "Missing regression target: #{name}" unless source.include?(original)

    File.write(file, source.sub(original, regression))
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rubocop", "--format", "json", "--cache", "false", chdir: project)
    raise "RuboCop crashed: #{stderr}" unless [0, 1].include?(status.exitstatus)

    cops = JSON.parse(stdout).fetch("files").flat_map { |entry| entry.fetch("offenses").map { |o| o.fetch("cop_name") } }.uniq.sort
    raise "Unexpected lint result for #{name}: #{cops}" unless cops == expected_cops

    stdout, stderr, status = Open3.capture3(env, *command, "check", "--", RbConfig.ruby, "verify.rb", "--name", test, chdir: project)
    # A crash or missing dependency must never pass as detection of the regression.
    raise "Contract did not detect #{name}:\n#{stdout}\n#{stderr}" unless status.exitstatus == 1 && stdout.include?("1 failures, 0 errors")

    puts "PASS regression #{name}: lint=#{cops.empty? ? 'clean (semantic review required)' : cops.join(',')}; #{test} fails"
    if name == "partial_object"
      stdout, stderr, status = Open3.capture3(env, *command, "check", "--views", "--", RbConfig.ruby, "verify.rb", "--name", test, chdir: project)
      unless status.exitstatus == 1 && ["View lint: FAIL", "Pass @invoice as an explicit partial local", "1 failures, 0 errors"].all? { |text| stdout.include?(text) }
        raise "Optional view profile did not catch the input mismatch:\n#{stdout}\n#{stderr}"
      end
      puts "PASS optional views: partial input regression detected; rendering contract also runs and fails"
    end
  ensure
    File.write(file, source) if file && source
  end
end
