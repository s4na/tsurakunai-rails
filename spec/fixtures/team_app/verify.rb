# frozen_string_literal: true

require "active_record"
require "minitest/autorun"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
# Disposable consumer schema, not an application migration.
ActiveRecord::Schema.define do
  create_table(:accounts) { |t| t.integer :credit_cents, null: false, default: 0 }
  create_table :invoices do |t|
    t.references :account, null: false, foreign_key: true
    t.string :memo, null: false
    t.integer :amount_cents, null: false
    t.boolean :confirmed, null: false, default: false
  end
  create_table :deliveries do |t|
    t.references :invoice, null: false, foreign_key: true
    t.string :payload, null: false
  end
end

require_relative "app/models/account"
require_relative "app/models/invoice"
require_relative "app/models/delivery"
require_relative "app/operations/invoices/settle"

class TeamContractTest < Minitest::Test
  def setup
    Delivery.delete_all
    Invoice.delete_all
    Account.delete_all
    @account = Account.create!(credit_cents: 500)
    @invoice = @account.invoices.create!(memo: "first", amount_cents: 100)
  end

  def test_crud_has_no_hidden_business_side_effects
    assert @invoice.update(memo: "edited")
    refute @invoice.reload.confirmed?
    assert_equal 500, @account.reload.credit_cents
    assert_equal 0, Delivery.count
    refute @invoice.update(amount_cents: -1)
    assert_equal 100, @invoice.reload.amount_cents
  end

  def test_model_transition_has_explicit_identity_and_return_value
    assert_same @invoice, @invoice.confirm!(confirmed_by: @account)
    assert @invoice.reload.confirmed?
    assert_equal 500, @account.reload.credit_cents
    assert_equal 0, Delivery.count
    assert_raises(Invoice::InvalidTransition) { @invoice.confirm!(confirmed_by: @account) }
  end

  def test_other_account_cannot_settle
    other = Account.create!(credit_cents: 500)
    assert_raises(Invoice::Forbidden) { Invoices::Settle.new(invoice: @invoice, actor: other).call }
    refute @invoice.reload.confirmed?
    assert_equal [500, 500], [@account.reload.credit_cents, other.reload.credit_cents]
    assert_equal 0, Delivery.count
  end

  def test_operation_commits_both_aggregates_and_pending_delivery
    assert_same @invoice, Invoices::Settle.new(invoice: @invoice, actor: @account).call
    assert @invoice.reload.confirmed?
    assert_equal 400, @account.reload.credit_cents
    assert_equal [[@invoice.id, "first"]], Delivery.pluck(:invoice_id, :payload)
    assert_raises(Invoice::InvalidTransition) { Invoices::Settle.new(invoice: @invoice, actor: @account).call }
    assert_equal 400, @account.reload.credit_cents
    assert_equal 1, Delivery.count
  end

  def test_insufficient_credit_rolls_back_the_earlier_transition
    @account.update!(credit_cents: 50)
    assert_raises(Account::InsufficientCredit) { Invoices::Settle.new(invoice: @invoice, actor: @account).call }
    refute @invoice.reload.confirmed?
    assert_equal 50, @account.reload.credit_cents
    assert_equal 0, Delivery.count
  end

  def test_outer_rollback_does_not_leave_pending_work
    Invoice.transaction do
      Invoices::Settle.new(invoice: @invoice, actor: @account).call
      assert_equal 1, Delivery.count
      raise ActiveRecord::Rollback
    end
    refute @invoice.reload.confirmed?
    assert_equal 500, @account.reload.credit_cents
    assert_equal 0, Delivery.count
  end
end
