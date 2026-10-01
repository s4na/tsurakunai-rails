# frozen_string_literal: true

require "lint_roller"
require "pathname"

module RuboCop
  module TsurakunaiRails
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: "rubocop-tsurakunai-rails",
          version: Tsurakunai::Rails::VERSION,
          homepage: "https://github.com/s4na/tsurakunai-rails",
          description: "Focused Rails guardrails"
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../../config/default.yml")
        )
      end
    end
  end
end
