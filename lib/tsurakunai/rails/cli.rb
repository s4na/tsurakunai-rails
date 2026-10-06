# frozen_string_literal: true

require "fileutils"
require "optparse"
require_relative "version"

module Tsurakunai
  module Rails
    class CLI
      SKILL_NAMES = %w[tsurakunai-rails tsurakunai-rails-implement tsurakunai-rails-review].freeze
      ROOT = File.expand_path("../../..", __dir__)

      def self.run(arguments)
        new.run(arguments.dup)
      end

      def run(arguments)
        case arguments.shift
        when "init-policy" then init_policy(arguments)
        when "install-rules" then install_rules(arguments)
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

      def init_policy(arguments)
        options = { project: Dir.pwd }
        parser = OptionParser.new do |opts|
          opts.on("--project PATH") { |value| options[:project] = value }
        end
        parser.parse!(arguments)
        raise ArgumentError, "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

        project = File.realpath(options[:project])
        files = {
          "RAILS_TEAM_POLICY.md" => "skills/tsurakunai-rails/references/team-policy.md",
          ".rubocop-tsurakunai.yml" => "config/project.yml"
        }
        files.each_key do |name|
          destination = File.join(project, name)
          raise ArgumentError, "Already exists: #{destination}; review the team policy before replacing it" if File.exist?(destination) || File.symlink?(destination)
        end
        files.each do |name, source|
          FileUtils.cp(File.join(ROOT, source), File.join(project, name))
          puts "Created #{File.join(project, name)}"
        end
        puts "Merge into .rubocop.yml: inherit_from: .rubocop-tsurakunai.yml"
        puts "Approve required authentication hooks before checking; keep team exceptions in RAILS_TEAM_POLICY.md."
        puts "Existing .rubocop.yml, AGENTS.md and CLAUDE.md were not modified."
        0
      end

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
        destinations = SKILL_NAMES.map { |name| File.join(parent, name) }
        # Check every member before writing: the skills share packaged references.
        destinations.each do |destination|
          raise ArgumentError, "Already exists: #{destination}; review changes before replacing the skill set" if File.exist?(destination) || File.symlink?(destination)
        end

        FileUtils.mkdir_p(parent)
        SKILL_NAMES.zip(destinations).each do |name, destination|
          FileUtils.cp_r(File.join(ROOT, "skills", name), destination)
          puts "Installed #{VERSION}: #{destination}"
        end
        0
      end

      def install_rules(arguments)
        options = { project: Dir.pwd }
        parser = OptionParser.new do |opts|
          opts.on("--target TARGET", %w[codex claude]) { |value| options[:target] = value }
          opts.on("--project PATH") { |value| options[:project] = value }
        end
        parser.parse!(arguments)
        raise ArgumentError, "Specify --target codex or --target claude" unless options[:target]
        raise ArgumentError, "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?

        project = File.realpath(options[:project])
        policy = File.join(project, "RAILS_TEAM_POLICY.md")
        raise ArgumentError, "Missing RAILS_TEAM_POLICY.md; run init-policy or supply your team policy first" unless File.file?(policy)

        if options[:target] == "codex"
          override = File.join(project, "AGENTS.override.md")
          raise ArgumentError, "AGENTS.override.md takes precedence; merge config/agent_rules.md into your active instructions" if File.exist?(override) || File.symlink?(override)

          if custom_codex_instruction_config?(project)
            raise ArgumentError, "Custom Codex fallback configuration detected; merge config/agent_rules.md into your active instructions"
          end
          destination = File.join(project, "AGENTS.md")
        else
          %w[.claude .claude/rules].each do |directory|
            path = File.join(project, directory)
            raise ArgumentError, "Refusing symlinked instruction directory: #{path}; merge the rules manually" if File.symlink?(path)
          end
          destination = File.join(project, ".claude", "rules", "tsurakunai-rails.md")
        end
        raise ArgumentError, "Already exists: #{destination}; merge config/agent_rules.md manually without replacing your instructions" if File.exist?(destination) || File.symlink?(destination)

        FileUtils.mkdir_p(File.dirname(destination))
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL) do |file|
          file.write(File.read(File.join(ROOT, "config", "agent_rules.md")))
        end
        puts "Installed #{destination}; required contracts and prohibited forms use RAILS_TEAM_POLICY.md."
        puts "Start a new agent session and verify the project instruction source is loaded."
        0
      end

      def custom_codex_instruction_config?(project)
        codex_home = ENV.fetch("CODEX_HOME", File.join(Dir.home, ".codex"))
        paths = [File.join(codex_home, "config.toml"), "/etc/codex/config.toml"]
        paths << File.join(ENV.fetch("ProgramData"), "OpenAI", "Codex", "config.toml") if ENV.key?("ProgramData")
        paths.concat(Dir.glob(File.join(codex_home, "*.config.toml")))
        directory = project
        loop do
          paths << File.join(directory, ".codex", "config.toml")
          parent = File.dirname(directory)
          break if parent == directory

          directory = parent
        end
        # Do not resolve TOML profiles/precedence or risk hiding an active fallback.
        paths.uniq.any? do |path|
          File.file?(path) && File.read(path).include?("project_doc_fallback_filenames")
        end
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
          puts "View lint: FAIL (missing configuration)"
          return false
        end

        ok = run_check_command("View lint", "bundle", "exec", "erb_lint", "--lint-all")
        $stderr.puts "View lint failed; inspect diagnostics and ensure erb_lint is in your bundle." unless ok
        ok
      end

      def check(arguments)
        views = arguments.first == "--views"
        arguments.shift if views
        raise ArgumentError, "Usage: tsurakunai-rails check [--views] -- TEST_COMMAND [ARGUMENTS...]" unless arguments.shift == "--" && !arguments.empty?

        # Run tests even when a linter fails. No shell interpolation of test arguments.
        lint_ok = run_check_command("Ruby lint", "bundle", "exec", "rubocop", "--plugin", "rubocop-tsurakunai-rails")
        views_ok = views ? check_views : true
        puts "View lint: SKIPPED (use --views with an installed profile)" unless views
        test_ok = run_check_command("Tests", [arguments.first, arguments.first], *arguments.drop(1))
        puts "Design review still required: invoke the tsurakunai-rails-review skill and record evidence."
        lint_ok && views_ok && test_ok ? 0 : 1
      end

      def run_check_command(label, *command)
        success = system(*command)
        detail = if success
                   "PASS"
                 elsif success.nil?
                   "FAIL (could not start command)"
                 elsif $?.signaled?
                   "FAIL (signal #{$?.termsig})"
                 else
                   "FAIL (exit #{$?.exitstatus})"
                 end
        puts "#{label}: #{detail}"
        success
      end

      def usage
        <<~TEXT
          tsurakunai-rails #{VERSION}
          init-policy [--project PATH]
          install-rules --target codex|claude [--project PATH]
          install-skill --target codex|claude [--project PATH]
          install-view-lint [--strict-locals] [--project PATH]
          check [--views] -- TEST_COMMAND [ARGUMENTS...]
          version
        TEXT
      end
    end
  end
end
