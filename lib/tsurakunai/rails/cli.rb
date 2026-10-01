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
        when "install-view-lint" then install_view_lint(arguments)
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

      def install_view_lint(arguments)
        options = { project: Dir.pwd, strict: false }
        parser = OptionParser.new do |opts|
          opts.on("--project PATH") { |value| options[:project] = value }
          opts.on("--strict-locals") { options[:strict] = true }
        end
        parser.parse!(arguments)
        raise ArgumentError, "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

        destination = File.join(File.realpath(options[:project]), ".erb_lint.yml")
        raise ArgumentError, "Already exists: #{destination}; merge the profile manually" if File.exist?(destination) || File.symlink?(destination)

        loader = File.join(File.dirname(destination), ".erb_linters", "tsurakunai_partial_inputs.rb")
        raise ArgumentError, "Already exists: #{loader}; review changes before replacing it" if File.exist?(loader) || File.symlink?(loader)

        profile = options[:strict] ? "erb_lint_strict.yml" : "erb_lint.yml"
        FileUtils.mkdir_p(File.dirname(loader))
        File.write(loader, "require \"tsurakunai/rails/erb_lint/partial_inputs\"\n")
        FileUtils.cp(File.join(ROOT, "config", profile), destination)
        puts "Installed #{destination}; add erb_lint ~> 0.9 to your Gemfile."
        puts "Strict locals require support in your Rails version and template engine." if options[:strict]
        0
      end

      def check_views
        unless File.file?(".erb_lint.yml")
          $stderr.puts "View lint requires .erb_lint.yml; run install-view-lint or merge the profile into your configuration."
          return false
        end

        ok = system("bundle", "exec", "erb_lint", "--lint-all")
        $stderr.puts "View lint failed; inspect diagnostics and ensure erb_lint is in your bundle." unless ok
        ok
      end

      def check(arguments)
        views = arguments.first == "--views"
        arguments.shift if views
        raise ArgumentError, "Usage: tsurakunai-rails check [--views] -- TEST_COMMAND [ARGUMENTS...]" unless arguments.shift == "--" && !arguments.empty?

        # Run tests even when a linter fails. No shell interpolation of test arguments.
        lint_ok = system("bundle", "exec", "rubocop", "--plugin", "rubocop-tsurakunai-rails")
        views_ok = views ? check_views : true
        test_ok = system([arguments.first, arguments.first], *arguments.drop(1))
        puts "Design review still required: invoke the tsurakunai-rails skill and record evidence."
        lint_ok && views_ok && test_ok ? 0 : 1
      end

      def usage
        <<~TEXT
          tsurakunai-rails #{VERSION}
          install-skill --target codex|claude [--project PATH]
          install-view-lint [--strict-locals] [--project PATH]
          check [--views] -- TEST_COMMAND [ARGUMENTS...]
          version
        TEXT
      end
    end
  end
end
