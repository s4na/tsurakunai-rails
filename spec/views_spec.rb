# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "action_view"

RSpec.describe "View input guardrails" do
  let(:root) { File.expand_path("..", __dir__) }

  def lint(project, profile)
    FileUtils.cp(File.join(root, "config", profile), File.join(project, ".erb_lint.yml"))
    FileUtils.mkdir_p(File.join(project, ".erb_linters"))
    File.write(File.join(project, ".erb_linters", "tsurakunai_partial_inputs.rb"), "require \"#{root}/lib/tsurakunai/rails/erb_lint/partial_inputs\"\n")
    Open3.capture3({ "BUNDLE_GEMFILE" => ENV.fetch("BUNDLE_GEMFILE", File.join(root, "Gemfile")) },
                  "bundle", "exec", "erb_lint", "--lint-all", chdir: project)
  end

  def with_views
    Dir.mktmpdir do |project|
      views = File.join(project, "app", "views", "invoices")
      FileUtils.mkdir_p(views)
      yield project, views
    end
  end

  it "detects hidden partial inputs but accepts top-level instance variables and local inputs" do
    with_views do |project, views|
      File.write(File.join(views, "show.html.erb"), "<%= @invoice.number %>\n")
      partial = File.join(views, "_invoice.html.erb")
      File.write(partial, "<%= @invoice.number %>\n")
      stdout, stderr, status = lint(project, "erb_lint.yml")
      expect(status.exitstatus).to eq(1), stderr
      expect(stdout).to include("_invoice.html.erb")
      expect(stdout).not_to include("show.html.erb:")
      File.write(partial, "<%= invoice.number %>\n")
      _, stderr, status = lint(project, "erb_lint.yml")
      expect(status.success?).to be(true), stderr
    end
  end

  it "requires a signature only in the strict profile and accepts Rails block helpers and collection locals" do
    with_views do |project, views|
      partial = File.join(views, "_invoice.html.erb")
      content = "<%= form_with model: invoice do |form| %>\n<%= form.text_field :number %>\n<% end %>\n"
      File.write(partial, content)
      _, stderr, status = lint(project, "erb_lint.yml")
      expect(status.success?).to be(true), stderr
      stdout, stderr, status = lint(project, "erb_lint_strict.yml")
      expect(status.exitstatus).to eq(1), stderr
      expect(stdout).to include("strict locals")
      File.write(partial, "<%# locals: (invoice:) %>\n#{content}")
      _, stderr, status = lint(project, "erb_lint_strict.yml")
      expect(status.success?).to be(true), stderr
    end
  end

  it "does not detect variable-like text and allows a narrowly reviewed exception" do
    with_views do |project, views|
      File.write(File.join(views, "_invoice.html.erb"), "<p>@invoice</p><%# @invoice %><%= '@invoice' %>\n")
      _, stderr, status = lint(project, "erb_lint.yml")
      expect(status.success?).to be(true), stderr
      File.write(File.join(views, "_invoice.html.erb"), "<%= @invoice.number %> <%# erb_lint:disable TsurakunaiPartialInputs %>\n")
      _, stderr, status = lint(project, "erb_lint.yml")
      expect(status.success?).to be(true), stderr
    end
  end

  it "detects variables inside incomplete block fragments and interpolation with Unicode locations" do
    with_views do |project, views|
      # Literal template interpolation must be evaluated by Action View, not this test.
      # rubocop:disable Lint/InterpolationCheck
      File.write(File.join(views, "_invoice.html.erb"), '<% if @can_edit %><%= "請求 #{@invoice.number}" %><% end %>')
      # rubocop:enable Lint/InterpolationCheck
      stdout, stderr, status = lint(project, "erb_lint.yml")
      expect(status.exitstatus).to eq(1), stderr
      expect(stdout).to include("@can_edit", "@invoice")
    end
  end

  it "reports structural parser errors instead of treating them as a checked template" do
    with_views do |project, views|
      File.write(File.join(views, "_invoice.html.erb"), '<div ="a">')
      stdout, stderr, status = lint(project, "erb_lint.yml")
      expect(status.exitstatus).to eq(1), stderr
      expect(stdout).to include("_invoice.html.erb")
    end
  end

  it "renders explicit inputs without inheriting a stale instance variable and enforces required locals" do
    with_views do |_project, views|
      File.write(File.join(views, "_invoice.html.erb"), <<~ERB)
        <%# locals: (invoice:, can_edit: false) %>
        <span><%= invoice.number %></span>
        <% if can_edit %><button>編集</button><% end %>
      ERB
      view = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new([File.dirname(views)]), {}, nil)
      invoice = Struct.new(:number).new("INV-1")
      other = Struct.new(:number).new("INV-2")
      view.assign(invoice: other, can_edit: true)
      rendered = view.render(partial: "invoices/invoice", locals: { invoice: invoice })
      expect(rendered).to include("INV-1")
      expect(rendered).not_to include("INV-2", "編集")
      expect(view.render(partial: "invoices/invoice", locals: { invoice: other, can_edit: true })).to include("INV-2", "編集")
      expect { view.render(partial: "invoices/invoice", locals: {}) }.to raise_error(ActionView::Template::Error, /missing local|missing keyword/)
      expect { view.render(partial: "invoices/invoice", locals: { invoice: invoice, typo: true }) }.to raise_error(ActionView::Template::Error, /unknown local|unknown keyword/)
    end
  end
end
