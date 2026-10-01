# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      class DefaultScope < Base
        RESTRICT_ON_SEND = %i[default_scope].freeze
        MSG = "Use a named scope and apply it explicitly; default_scope hides query and creation behavior."

        def on_send(node)
          return unless node.receiver.nil? || node.receiver.self_type?

          add_offense(node.loc.selector)
        end
        alias on_csend on_send
      end
    end
  end
end
