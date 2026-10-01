# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"
require "json"
require "yaml"

RSpec.describe "Focused upstream rules through the public plugin" do
  # Independent behavior examples, not generated from config/default.yml.
  rails_cases = {
    "ActiveRecordOverride" => ["app/models/invoice.rb", "def save; super; end", "def normalize_memo; memo.strip; end"],
    "DuplicateAssociation" => ["app/models/invoice.rb", "belongs_to :account\nbelongs_to :account", "belongs_to :account\nbelongs_to :owner"],
    "AfterCommitOverride" => ["app/models/invoice.rb", "after_create_commit :notify\nafter_update_commit :notify", "after_save_commit :notify"],
    "EnumHash" => ["app/models/invoice.rb", "enum :status, [:draft, :paid]", "enum :status, { draft: 0, paid: 1 }"],
    "EnumUniqueness" => ["app/models/invoice.rb", "enum :status, { draft: 0, paid: 0 }", "enum :status, { draft: 0, paid: 1 }"],
    "SaveBang" => ["app/controllers/invoices_controller.rb", "invoice.update(memo: 'paid')\nrender :show", "if invoice.update(memo: 'paid')\nrender :show\nelse\nrender :edit\nend"],
    "HasManyOrHasOneDependent" => ["app/models/invoice.rb", "has_many :line_items", "has_many :line_items, dependent: :restrict_with_exception"],
    "UniqueValidationWithoutIndex" => ["app/models/invoice.rb", "validates :external_id, uniqueness: { scope: :account_id }", "validates :external_id, uniqueness: { scope: :account_id }"],
    "AddColumnIndex" => ["db/migrate/example.rb", "add_column :invoices, :account_id, :integer, index: true", "add_column :invoices, :account_id, :integer\nadd_index :invoices, :account_id"],
    "DangerousColumnNames" => ["db/migrate/example.rb", "add_column :invoices, :save, :string", "add_column :invoices, :memo, :string"],
    "NotNullColumn" => ["db/migrate/example.rb", "add_column :invoices, :memo, :string, null: false", "add_column :invoices, :memo, :string, null: true"],
    "UnusedRenderContent" => ["app/controllers/invoices_controller.rb", "render json: { ok: true }, status: 204", "render json: { ok: true }, status: 200"]
  }.freeze

  rspec_cases = {
    "AnyInstance" => ["allow_any_instance_of(Invoice).to receive(:save!)", "allow(invoice).to receive(:save!)"],
    "MessageChain" => ["allow(invoice).to receive_message_chain(:account, :name)", "allow(account).to receive(:name)"],
    "SubjectStub" => ["subject(:invoice) { Invoice.new }\nit { allow(invoice).to receive(:total) }", "subject(:invoice) { Invoice.new }\nit { expect(invoice.total).to eq(10) }"],
    "VerifiedDoubles" => ["let(:invoice) { double(total: 10) }", "let(:invoice) { instance_double(Invoice, total: 10) }"],
    "UnspecifiedException" => ["it { expect { invoice.save! }.to raise_error }", "it { expect { invoice.save! }.to raise_error(ValidationError) }"],
    "OverwritingSetup" => ["let(:amount) { 10 }\nlet(:amount) { 20 }", "let(:amount) { 10 }\nlet(:tax) { 20 }"],
    "VoidExpect" => ["it { expect(invoice.total) }", "it { expect(invoice.total).to eq(10) }"]
  }.freeze

  def with_project(rspec: false, policies: false)
    Dir.mktmpdir do |project|
      config = <<~YAML
        plugins:
          - rubocop-tsurakunai-rails
        AllCops:
          NewCops: enable
          TargetRubyVersion: 3.0
          TargetRailsVersion: 7.1
          SuggestExtensions: false
      YAML
      if rspec || policies
        config += <<~YAML
          inherit_gem:
            rubocop-tsurakunai-rails:
              #{"- config/rspec.yml" if rspec}
              #{"- config/policies.yml" if policies}
        YAML
      end
      File.write(File.join(project, ".rubocop.yml"), config)
      FileUtils.mkdir_p(File.join(project, "db"))
      # Schema is a simulated consumer artifact, not an application migration.
      File.write(File.join(project, "db", "schema.rb"), <<~RUBY)
        ActiveRecord::Schema[7.1].define(version: 1) do
          create_table "invoices", force: :cascade do |t|
            t.string "external_id"
            t.integer "account_id"
          end
        end
      RUBY
      yield project
    end
  end

  def rubocop(project, *arguments)
    # Preserve the source bundle while evaluating the consumer's cwd/schema.
    env = { "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE", File.expand_path("../Gemfile", __dir__)) }
    Open3.capture3(env, "bundle", "exec", "rubocop", "--config", File.join(project, ".rubocop.yml"),
                  *arguments, chdir: project)
  end

  rails_cases.each do |name, (path, bad, good)|
    it "detects and accepts the meaningful #{name} cases through the selected plugin profile" do
      with_project do |project|
        file = File.join(project, path)
        FileUtils.mkdir_p(File.dirname(file))
        if path.start_with?("app/models")
          bad = "class Invoice < ApplicationRecord\n#{bad}\nend\n"
          good = "class Invoice < ApplicationRecord\n#{good}\nend\n"
        end
        [bad, good].each_with_index do |source, index|
          File.write(file, source)
          if name == "UniqueValidationWithoutIndex" && index == 1
            schema_path = File.join(project, "db", "schema.rb")
            schema = File.read(schema_path).sub('t.integer "account_id"', 't.integer "account_id"' + "\n" + 't.index ["account_id", "external_id"], unique: true')
            File.write(schema_path, schema)
          end
          stdout, stderr, status = rubocop(project, "--only", "Rails/#{name}", "--format", "json", "--cache", "false", "--autocorrect-all", file)
          report = JSON.parse(stdout)
          offenses = report.fetch("files").flat_map { |entry| entry.fetch("offenses") }
          expect(status.exitstatus).to eq(index.zero? ? 1 : 0), "#{stderr}\n#{stdout}"
          expect(offenses.map { |o| o.fetch("cop_name") }).to(index.zero? ? include("Rails/#{name}") : be_empty)
          expect(File.read(file)).to eq(source), "Baseline must not autocorrect #{name}"
        end
      end
    end
  end

  rspec_cases.each do |name, (bad, good)|
    it "detects and accepts the meaningful RSpec/#{name} cases through the default plugin" do
      with_project do |project|
        file = File.join(project, "spec", "invoice_spec.rb")
        FileUtils.mkdir_p(File.dirname(file))
        [bad, good].each_with_index do |body, index|
          source = "RSpec.describe Invoice do\n#{body}\nend\n"
          File.write(file, source)
          stdout, stderr, status = rubocop(project, "--only", "RSpec/#{name}", "--format", "json", "--cache", "false", "--autocorrect-all", file)
          expect(status.exitstatus).to eq(index.zero? ? 1 : 0), "#{stderr}\n#{stdout}"
          offenses = JSON.parse(stdout).fetch("files").flat_map { |entry| entry.fetch("offenses") }
          expect(offenses.map { |o| o.fetch("cop_name") }).to(index.zero? ? include("RSpec/#{name}") : be_empty)
          expect(File.read(file)).to eq(source), "Defaults must not autocorrect RSpec/#{name}"
        end
      end
    end
  end

  it "enables only the selected upstream rules and allows the consumer's explicit overrides" do
    with_project do |project|
      stdout, stderr, status = rubocop(project, "--show-cops")
      expect(status.success?).to be(true), stderr
      cops = YAML.safe_load(stdout, permitted_classes: [Regexp, Symbol])
      rails = cops.select { |name, config| name.start_with?("Rails/") && config["Enabled"] == true }.keys
      rspec = cops.select { |name, config| name.start_with?("RSpec/") && config["Enabled"] == true }.keys
      expect(rails).to match_array(rails_cases.keys.map { |name| "Rails/#{name}" })
      custom = cops.select { |name, config| name.start_with?("TsurakunaiRails/") && config["Enabled"] == true }.keys
      expect(custom).to match_array(%w[ControllerCallbacks DefaultScope ValidationBypass ModelRequestContext].map { |name| "TsurakunaiRails/#{name}" })
      expect(rspec).to match_array(rspec_cases.keys.map { |name| "RSpec/#{name}" })

      File.open(File.join(project, ".rubocop.yml"), "a") do |file|
        file.write("\nRails/SaveBang:\n  Enabled: false\nRails/Delegate:\n  Enabled: true\nRSpec/AnyInstance:\n  Enabled: false\n")
      end
      stdout, stderr, status = rubocop(project, "--show-cops")
      expect(status.success?).to be(true), stderr
      cops = YAML.safe_load(stdout, permitted_classes: [Regexp, Symbol])
      expect(cops.fetch("Rails/SaveBang").fetch("Enabled")).to be(false)
      expect(cops.fetch("Rails/Delegate").fetch("Enabled")).to be(true)
      expect(cops.fetch("RSpec/AnyInstance").fetch("Enabled")).to be(false)
    end
  end
  it "keeps the legacy policies preset compatible and preserves individual overrides" do
    with_project(policies: true, rspec: true) do |project|
      stdout, stderr, status = rubocop(project, "--show-cops")
      expect(status.success?).to be(true), stderr
      cops = YAML.safe_load(stdout, permitted_classes: [Regexp, Symbol])
      expect(cops.select { |name, config| name.start_with?("Rails/") && config["Enabled"] == true }.keys)
        .to match_array(rails_cases.keys.map { |name| "Rails/#{name}" })
      %w[ControllerCallbacks DefaultScope ValidationBypass ModelRequestContext].each do |name|
        expect(cops.fetch("TsurakunaiRails/#{name}").fetch("Enabled")).to be(true)
      end
      File.open(File.join(project, ".rubocop.yml"), "a") do |file|
        file.write("\nTsurakunaiRails/ControllerCallbacks:\n  Enabled: false\n")
      end
      stdout, stderr, status = rubocop(project, "--show-cops")
      expect(status.success?).to be(true), stderr
      expect(YAML.safe_load(stdout, permitted_classes: [Regexp, Symbol]).fetch("TsurakunaiRails/ControllerCallbacks").fetch("Enabled")).to be(false)
    end
  end

end
