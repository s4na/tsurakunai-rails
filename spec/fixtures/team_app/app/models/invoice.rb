# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  class Forbidden < StandardError; end
  class InvalidTransition < StandardError; end

  belongs_to :account
  validates :memo, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }

  def confirm!(confirmed_by:)
    with_lock do
      raise Forbidden unless account_id == confirmed_by.id
      raise InvalidTransition if confirmed?

      update!(confirmed: true)
    end
    self
  end
end
