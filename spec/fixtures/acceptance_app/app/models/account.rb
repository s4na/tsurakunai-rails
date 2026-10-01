# frozen_string_literal: true

class Account < ActiveRecord::Base
  has_many :invoices, dependent: :restrict_with_exception
end
