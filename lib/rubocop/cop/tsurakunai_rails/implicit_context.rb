# frozen_string_literal: true

module RuboCop
  module Cop
    module TsurakunaiRails
      # Current is a project naming convention, not inferred CurrentAttributes type.
      class ImplicitContext < Base
        MSG = "Pass actor, tenant and other context explicitly; read Current only at the HTTP boundary."

        def on_const(node)
          return unless node.const_name.split("::").last == "Current"
          return if declaration?(node)
          return if cop_config.fetch("AllowedConstants", []).include?(node.const_name)

          add_offense(node)
        end

        private

        def declaration?(node)
          parent = node.parent
          parent && (parent.class_type? || parent.module_type?) && parent.children.first.equal?(node)
        end
      end
    end
  end
end
