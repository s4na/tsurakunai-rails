# frozen_string_literal: true

# Durable pending work; this fixture does not claim to implement a delivery worker.
class Delivery < ActiveRecord::Base
  belongs_to :invoice
  validates :payload, presence: true
end
