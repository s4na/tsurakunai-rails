# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # AST cannot infer Active Record receivers: report explicit bypass forms
      # in model files and leave dynamic dispatch/other layers to review.
      class ValidationBypass < Base
        RESTRICT_ON_SEND = %i[update_attribute update_attribute! update_column update_columns save save!].freeze
        MSG = "This write bypasses validation; use a validated write or document why DB constraints make it safe."
        BYPASS_METHODS = %i[update_attribute update_attribute! update_column update_columns].freeze

        def on_send(node)
          bypass = BYPASS_METHODS.include?(node.method_name) || validation_disabled?(node)
          add_offense(node.loc.selector) if bypass
        end
        alias on_csend on_send

        private

        def validation_disabled?(node)
          options = node.last_argument
          return false unless options&.hash_type?

          options.pairs.any? do |pair|
            pair.key.sym_type? && pair.key.value == :validate && pair.value.false_type?
          end
        end
      end
    end
  end
end
