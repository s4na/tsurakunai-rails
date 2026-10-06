# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # Shared behavior is a collaborator with explicit inputs, not an injected API.
      class Concern < Base
        RESTRICT_ON_SEND = %i[extend include].freeze
        MSG = "Use an explicit collaborator instead of injecting business behavior with ActiveSupport::Concern."

        def on_send(node)
          return unless node.receiver.nil? || node.receiver.self_type?

          node.arguments.each do |argument|
            add_offense(argument) if argument.const_type? && argument.const_name == "ActiveSupport::Concern"
          end
        end
        alias on_csend on_send
      end
    end
  end
end
