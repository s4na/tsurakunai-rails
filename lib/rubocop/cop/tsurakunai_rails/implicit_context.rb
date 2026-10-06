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
          return if allowed_constant?(node)

          add_offense(node)
        end

        private

        def allowed_constant?(node)
          allowed = cop_config.fetch("AllowedConstants", [])
          return true if allowed.include?(node.const_name)
          return false if node.namespace

          lexical_namespaces(node).any? { |namespace| allowed.include?("#{namespace}::Current") }
        end

        def lexical_namespaces(node)
          child = node
          scopes = node.each_ancestor.filter_map do |ancestor|
            scope = ancestor if (ancestor.class_type? || ancestor.module_type?) && ancestor.body.equal?(child)
            child = ancestor
            scope
          end
          scopes.reverse_each.each_with_object([]) do |scope, namespaces|
            definition = scope.children.first
            name = definition.const_name
            absolute = definition.each_descendant(:cbase).any?
            namespaces << (absolute || namespaces.empty? ? name : "#{namespaces.last}::#{name}")
          end
        end

        def declaration?(node)
          parent = node.parent
          parent && (parent.class_type? || parent.module_type?) && parent.children.first.equal?(node)
        end
      end
    end
  end
end
