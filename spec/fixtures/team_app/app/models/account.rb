# frozen_string_literal: true

class Account < ActiveRecord::Base
  class InsufficientCredit < StandardError; end

  has_many :invoices, dependent: :restrict_with_exception
  validates :credit_cents, numericality: { greater_than_or_equal_to: 0 }

  def debit!(amount_cents:)
    with_lock do
      raise InsufficientCredit unless amount_cents.positive? && credit_cents >= amount_cents

      update!(credit_cents: credit_cents - amount_cents)
    end
    self
  end
end
