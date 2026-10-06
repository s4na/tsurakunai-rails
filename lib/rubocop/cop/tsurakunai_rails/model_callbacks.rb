# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # Policy: a save must not silently become a different business operation.
      # Explicit transaction callbacks on a receiver are not model registrations.
      class ModelCallbacks < Base
        CALLBACKS = %i[
          before_validation after_validation before_save around_save after_save
          before_create around_create after_create before_update around_update after_update
          before_destroy around_destroy after_destroy after_initialize after_find after_touch
          before_commit after_commit after_rollback after_save_commit after_create_commit after_update_commit
          after_destroy_commit set_callback
        ].freeze
        RESTRICT_ON_SEND = CALLBACKS
        MSG = "Call business steps explicitly; keep only team-approved named lifecycle hooks."

        def on_send(node)
          return unless model_receiver?(node.receiver)
          return if allowed_callback?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send

        private

        def model_receiver?(receiver)
          receiver.nil? || receiver.self_type? || receiver.const_type? ||
            ((receiver.send_type? || receiver.csend_type?) && receiver.method?(:class))
        end

        def allowed_callback?(node)
          return false if node.method?(:set_callback) || node.block_node

          names = node.arguments.reject(&:hash_type?)
          allowed = cop_config.fetch("AllowedCallbacks", {}).fetch(node.method_name.to_s, [])
          !names.empty? && names.all? do |argument|
            (argument.sym_type? || argument.str_type?) && allowed.include?(argument.value.to_s)
          end
        end
      end
    end
  end
end
