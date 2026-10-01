# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # A boundary policy, not type inference: controller helpers should not
      # become implicit inputs to persistence and business behavior.
      class ModelRequestContext < Base
        RESTRICT_ON_SEND = %i[params session cookies flash request response current_user current_account].freeze
        MSG = "Pass input and identity explicitly; do not read controller request context from a model."

        def on_send(node)
          return unless node.receiver.nil? || node.receiver.self_type?
          return if cop_config.fetch("AllowedMethods", []).include?(node.method_name.to_s)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
