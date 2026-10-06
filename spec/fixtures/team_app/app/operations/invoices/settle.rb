# frozen_string_literal: true

module Invoices
  class Settle
    def initialize(invoice:, actor:)
      @invoice = invoice
      @actor = actor
    end

    def call
      Invoice.transaction do
        @invoice.confirm!(confirmed_by: @actor)
        @actor.debit!(amount_cents: @invoice.amount_cents)
        Delivery.create!(invoice: @invoice, payload: @invoice.memo)
      end
      @invoice
    end
  end
end
