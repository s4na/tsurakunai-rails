# frozen_string_literal: true

require "active_record"
require "action_controller"
require "action_view"
require "rack/mock"
require "minitest/autorun"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
# Disposable test schema, not an application migration.
ActiveRecord::Schema.define do
  create_table(:accounts) { |t| t.string :name, null: false }
  create_table :invoices do |t|
    t.references :account, null: false, foreign_key: true
    t.string :memo, null: false
    t.integer :amount_cents, null: false
  end
end

require_relative "app/models/account"
require_relative "app/models/invoice"
require_relative "app/controllers/invoices_controller"
InvoicesController.prepend_view_path(File.expand_path("app/views", __dir__))
AcceptanceRoutes = ActionDispatch::Routing::RouteSet.new
AcceptanceRoutes.draw do
  get "/invoices", to: "invoices#index"
  patch "/invoices/:id", to: "invoices#update"
end

class AcceptanceTest < Minitest::Test
  def setup
    Invoice.delete_all
    Account.delete_all
    @account = Account.create!(name: "A")
    @other = Account.create!(name: "B")
    @invoice = @account.invoices.create!(memo: "first", amount_cents: 100)
    @second = @account.invoices.create!(memo: "second", amount_cents: 200)
    @foreign = @other.invoices.create!(memo: "private", amount_cents: 300)
    Invoice.notifications = []
  end

  def call(method, path, account: @account, invoice: nil)
    options = { method: method, "acceptance.account" => account }
    options[:params] = { invoice: invoice } if invoice
    env = Rack::MockRequest.env_for(path, options)
    status, _, response = AcceptanceRoutes.call(env)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [status, body]
  end

  def test_unauthenticated_update_is_rejected_without_writing
    status, = call("PATCH", "/invoices/#{@invoice.id}", account: nil, invoice: { memo: "intrusion" })
    assert_equal 401, status
    assert_equal "first", @invoice.reload.memo
    assert_empty Invoice.notifications
  end

  def test_other_tenant_is_not_readable_or_writable
    status, = call("PATCH", "/invoices/#{@foreign.id}", invoice: { memo: "intrusion" })
    assert_equal 404, status
    assert_equal "private", @foreign.reload.memo
    assert_empty Invoice.notifications
  end

  def test_validation_failure_preserves_input_errors_and_database
    status, body = call("PATCH", "/invoices/#{@invoice.id}", invoice: { memo: "typed <value>", amount_cents: -1 })
    assert_equal 422, status
    assert_includes body, "Amount cents must be greater than 0"
    assert_includes body, "typed &lt;value&gt;"
    assert_includes body, 'value="-1"'
    assert_equal ["first", 100], [@invoice.reload.memo, @invoice.amount_cents]
    assert_empty Invoice.notifications
  end

  def test_success_saves_only_permitted_values_and_notifies_after_commit
    status, body = call("PATCH", "/invoices/#{@invoice.id}", invoice: { memo: "updated", account_id: @other.id })
    assert_equal [200, "saved"], [status, body]
    assert_equal ["updated", @account.id], [@invoice.reload.memo, @invoice.account_id]
    assert_equal [@invoice.id], Invoice.notifications
  end

  def test_model_operation_works_without_a_request_and_notifies_on_both_events
    invoice = @account.invoices.create!(memo: "from job", amount_cents: 400)
    invoice.update!(memo: "job updated")
    assert_equal "job updated", invoice.reload.memo
    assert_equal [invoice.id, invoice.id], Invoice.notifications
  end

  def test_collection_renders_each_object_without_leaking_other_tenants_or_mutating_data
    before = Invoice.order(:id).pluck(:id, :memo, :amount_cents)
    2.times do
      status, body = call("GET", "/invoices")
      assert_equal 200, status
      assert_includes body, "first: 100"
      assert_includes body, "second: 200"
      refute_includes body, "private"
    end
    assert_equal before, Invoice.order(:id).pluck(:id, :memo, :amount_cents)
    assert_empty Invoice.notifications
  end
end
