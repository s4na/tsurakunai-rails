# frozen_string_literal: true

require "erb_lint"
require "ripper"

module ERBLint
  module Linters
    # Inspect Ruby tokens inside ERB, including incomplete block fragments.
    # Template text, comments and ordinary string contents are not Ruby inputs.
    class TsurakunaiPartialInputs < Linter
      include LinterRegistry

      def run(processed_source)
        return unless File.basename(processed_source.filename).start_with?("_")

        processed_source.ast.descendants(:erb).each do |node|
          indicator, _, code, = *node
          next if indicator&.children&.first == "#" || !code

          source = code.loc.source
          lines = source.lines
          Ripper.lex(source).each do |(line, column), event, token, _state|
            next unless event == :on_ivar

            # Ripper columns are bytes; Parser source ranges count characters.
            offset = lines.take(line - 1).join.length + lines.fetch(line - 1).byteslice(0, column).length
            position = code.loc.begin_pos + offset
            add_offense(processed_source.to_source_range(position...(position + token.length)),
                        "Pass #{token} as an explicit partial local; review all render callers before changing it.")
          end
        end
      end
    end
  end
end
