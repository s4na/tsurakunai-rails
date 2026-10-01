# frozen_string_literal: true

require "fileutils"
require "optparse"
require_relative "version"

module Tsurakunai
  module Rails
    class CLI
      SKILL_NAME = "tsurakunai-rails"
      ROOT = File.expand_path("../../..", __dir__)

      def self.run(arguments)
        new.run(arguments.dup)
      end

      def run(arguments)
        case arguments.shift
        when "install-skill" then install_skill(arguments)
        when "check" then check(arguments)
        when "version", "--version" then puts VERSION; 0
        when "help", "--help", nil then puts usage; 0
        else
          $stderr.puts usage
          2
        end
      rescue OptionParser::ParseError, ArgumentError, SystemCallError => e
        $stderr.puts e.message
        2
      end

      private

      def install_skill(arguments)
        options = { project: Dir.pwd }
        parser = OptionParser.new do |opts|
          opts.on("--target TARGET", %w[codex claude]) { |value| options[:target] = value }
          opts.on("--project PATH") { |value| options[:project] = value }
        end
        parser.parse!(arguments)
        raise ArgumentError, "Specify --target codex or --target claude" unless options[:target]
        raise ArgumentError, "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

        project = File.realpath(options[:project])
        directory = options[:target] == "codex" ? ".agents" : ".claude"
        parent = File.join(project, directory, "skills")
        destination = File.join(parent, SKILL_NAME)
        raise ArgumentError, "Already exists: #{destination}; review changes before replacing it" if File.exist?(destination) || File.symlink?(destination)

        FileUtils.mkdir_p(parent)
        FileUtils.cp_r(File.join(ROOT, "skills", SKILL_NAME), destination)
        puts "Installed #{VERSION}: #{destination}"
        0
      end

      def check(arguments)
        raise ArgumentError, "Usage: tsurakunai-rails check -- TEST_COMMAND [ARGUMENTS...]" unless arguments.shift == "--" && !arguments.empty?

        # Run both even when lint fails. No shell interpolation of test arguments.
        lint_ok = system("bundle", "exec", "rubocop", "--plugin", "rubocop-tsurakunai-rails")
        test_ok = system([arguments.first, arguments.first], *arguments.drop(1))
        puts "Design review still required: invoke the tsurakunai-rails skill and record evidence."
        lint_ok && test_ok ? 0 : 1
      end

      def usage
        <<~TEXT
          tsurakunai-rails #{VERSION}
          install-skill --target codex|claude [--project PATH]
          check -- TEST_COMMAND [ARGUMENTS...]
          version
        TEXT
      end
    end
  end
end
