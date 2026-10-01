# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  belongs_to :account
  validates :memo, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  after_save_commit :record_notification

  class_attribute :notifications, default: []

  def record_notification
    self.class.notifications << id
  end
end
