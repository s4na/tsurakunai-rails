# frozen_string_literal: true

require "tmpdir"
require "open3"
require "json"
require "fileutils"

RSpec.describe "RuboCop plugin integration" do
  def run_cop(project, *args)
    Open3.capture3("bundle", "exec", "rubocop", "--config", File.join(project, ".rubocop.yml"),
                  "--only", "TsurakunaiRails", "--format", "json", "--cache", "false", project, *args)
  end

  it "checks design defaults without autocorrection and honors individual opt-outs" do
    Dir.mktmpdir do |project|
      File.write(File.join(project, ".rubocop.yml"), <<~YAML)
        plugins:
          - rubocop-tsurakunai-rails
        AllCops:
          NewCops: enable
          TargetRubyVersion: 3.0
          SuggestExtensions: false
        TsurakunaiRails/ImplicitContext:
          AllowedConstants: [Electric::Current]
      YAML
      sources = {
        "app/controllers/invoices_controller.rb" => "class InvoicesController\n  before_action :load_invoice\nend\n",
        "app/controllers/concerns/audit.rb" => "module Audit\n  after_action { audit }\nend\n",
        "app/models/invoice.rb" => "class Invoice\n  before_commit :collect_payment\n  Invoice.after_commit :collect_payment\n  default_scope { where(active: true) }\n  def finish\n    Current.user\n    update_columns(status: 'done')\n  end\nend\n",
        "app/models/measurement.rb" => "module Electric\n  def self.measure\n    Current.measure\n  end\nend\n",
        "app/models/allowed.rb" => "class Allowed\n  # Reviewed repair: constraints guarantee validity.\n  # rubocop:disable TsurakunaiRails/ValidationBypass\n  def repair\n    update_column(:status, 'done')\n  end\n  # rubocop:enable TsurakunaiRails/ValidationBypass\nend\n",
        "app/models/concerns/input.rb" => "module Input\n  def normalize\n    params.fetch(:memo)\n  end\nend\n",
        "lib/other.rb" => "before_action :step\ndefault_scope { all }\nrecord.update_columns(status: 'done')\nparams.fetch(:memo)\n"
      }
      sources.each do |name, source|
        path = File.join(project, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, source)
      end
      stdout, stderr, status = run_cop(project, "--autocorrect")
      expect(stderr).not_to include("unrecognized", "Error:")
      expect(status.exitstatus).to eq(1), stderr
      report = JSON.parse(stdout)
      offenses = report.fetch("files").flat_map { |file| file.fetch("offenses") }
      expect(offenses.map { |offense| offense.fetch("cop_name") }.tally).to eq(
        "TsurakunaiRails/ControllerCallbacks" => 2,
        "TsurakunaiRails/ModelCallbacks" => 2,
        "TsurakunaiRails/ImplicitContext" => 1,
        "TsurakunaiRails/ModelRequestContext" => 1,
        "TsurakunaiRails/DefaultScope" => 1,
        "TsurakunaiRails/ValidationBypass" => 1
      )
      expect(offenses).to all(include("correctable" => false))
      sources.each { |name, source| expect(File.read(File.join(project, name))).to eq(source) }
      File.open(File.join(project, ".rubocop.yml"), "a") do |file|
        file.write("\nTsurakunaiRails/DefaultScope:\n  Enabled: false\n")
      end
      stdout, stderr, status = run_cop(project)
      expect(status.exitstatus).to eq(1), stderr
      remaining = JSON.parse(stdout).fetch("files").flat_map { |file| file.fetch("offenses") }
      expect(remaining.map { |offense| offense.fetch("cop_name") }.uniq).to match_array(
        %w[TsurakunaiRails/ControllerCallbacks TsurakunaiRails/ModelCallbacks TsurakunaiRails/ImplicitContext TsurakunaiRails/ModelRequestContext TsurakunaiRails/ValidationBypass]
      )
    end
  end
end
