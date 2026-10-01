# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # Intentional policy: make controller execution order visible in actions.
      class ControllerCallbacks < Base
        CALLBACKS = %i[
          before_action after_action around_action
          append_before_action append_after_action append_around_action
          prepend_before_action prepend_after_action prepend_around_action
          before_filter after_filter around_filter
          append_before_filter append_after_filter append_around_filter
          prepend_before_filter prepend_after_filter prepend_around_filter
        ].freeze
        RESTRICT_ON_SEND = CALLBACKS
        MSG = "Make action flow explicit; move this callback into the action or document a scoped exception."

        def on_send(node)
          return unless node.receiver.nil? || node.receiver.self_type?
          return if allowed_callback?(node)

          add_offense(node.loc.selector)
        end
        alias on_csend on_send

        private

        def allowed_callback?(node)
          # Mixed or dynamic registrations are never silently approved.
          arguments = node.arguments.reject(&:hash_type?)
          return false if arguments.empty? || node.block_node

          arguments.all? do |argument|
            (argument.sym_type? || argument.str_type?) &&
              cop_config.fetch("AllowedMethods", []).include?(argument.value.to_s)
          end
        end
      end
    end
  end
end
