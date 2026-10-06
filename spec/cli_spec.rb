# frozen_string_literal: true

require "tsurakunai/rails/cli"
require "tmpdir"
require "open3"
require "rbconfig"

RSpec.describe Tsurakunai::Rails::CLI do
  def cli(*arguments, env: {}, **options)
    Dir.mktmpdir("tsurakunai-codex-home-") do |codex_home|
      Open3.capture3({ "CODEX_HOME" => codex_home }.merge(env), RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
                    File.expand_path("../exe/tsurakunai-rails", __dir__), *arguments, **options)
    end
  end

  it "creates portable team decisions and a usable profile without overwriting project instructions" do
    Dir.mktmpdir do |project|
      File.write(File.join(project, "AGENTS.md"), "existing instructions")
      File.write(File.join(project, ".rubocop.yml"), "existing lint")
      stdout, stderr, status = cli("init-policy", "--project", project)
      expect(status.success?).to be(true), stderr
      expect(stdout).to include("inherit_from: .rubocop-tsurakunai.yml")
      expect(File.read(File.join(project, "RAILS_TEAM_POLICY.md"))).to eq(
        File.read(File.expand_path("../skills/tsurakunai-rails/references/team-policy.md", __dir__))
      )
      expect(File.read(File.join(project, "AGENTS.md"))).to eq("existing instructions")
      expect(File.read(File.join(project, ".rubocop.yml"))).to eq("existing lint")
      File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team edits")
      _, error, second = cli("init-policy", "--project", project)
      expect(second.exitstatus).to eq(2)
      expect(error).to include("Already exists")
      expect(File.read(File.join(project, "RAILS_TEAM_POLICY.md"))).to eq("team edits")
    end
  end

  it "does not partially create a policy when its lint profile exists, even as a broken symlink" do
    Dir.mktmpdir do |project|
      File.symlink("missing-profile", File.join(project, ".rubocop-tsurakunai.yml"))
      _, stderr, status = cli("init-policy", "--project", project)
      expect(status.exitstatus).to eq(2)
      expect(stderr).to include("Already exists")
      expect(File).not_to exist(File.join(project, "RAILS_TEAM_POLICY.md"))
      expect(File.readlink(File.join(project, ".rubocop-tsurakunai.yml"))).to eq("missing-profile")
    end
  end

  %w[codex claude].each do |target|
    it "installs #{target} project rules pointing to the team's unchanged policy" do
      Dir.mktmpdir do |project|
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team-approved policy")
        File.write(File.join(project, "CLAUDE.md"), "existing Claude instructions")
        stdout, stderr, status = cli("install-rules", "--target", target, "--project", project)
        expect(status.success?).to be(true), stderr
        relative = target == "codex" ? "AGENTS.md" : ".claude/rules/tsurakunai-rails.md"
        expect(stdout).to include(File.join(project, relative))
        expect(File.read(File.join(project, relative))).to eq(File.read(File.expand_path("../config/agent_rules.md", __dir__)))
        expect(File.read(File.join(project, "RAILS_TEAM_POLICY.md"))).to eq("team-approved policy")
        expect(File.read(File.join(project, "CLAUDE.md"))).to eq("existing Claude instructions")
      end
    end

    it "preserves existing #{target} rules and refuses reinstallation" do
      Dir.mktmpdir do |project|
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
        relative = target == "codex" ? "AGENTS.md" : ".claude/rules/tsurakunai-rails.md"
        destination = File.join(project, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        File.write(destination, "existing team rules")
        _, stderr, status = cli("install-rules", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists", "merge")
        expect(File.read(destination)).to eq("existing team rules")
      end
    end

    it "preserves a broken symlink at the #{target} rule destination" do
      Dir.mktmpdir do |project|
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
        relative = target == "codex" ? "AGENTS.md" : ".claude/rules/tsurakunai-rails.md"
        destination = File.join(project, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        File.symlink("missing-rule", destination)
        _, stderr, status = cli("install-rules", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists")
        expect(File.readlink(destination)).to eq("missing-rule")
        expect(File).not_to exist(File.join(File.dirname(destination), "missing-rule"))
      end
    end
  end

  it "requires a policy and valid arguments before writing project rules" do
    Dir.mktmpdir do |project|
      %w[codex claude].each do |target|
        _, stderr, status = cli("install-rules", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Missing RAILS_TEAM_POLICY.md")
      end
      [[], ["--target", "unknown"], ["--target", "codex", "extra"]].each do |flags|
        _, _, status = cli("install-rules", *flags, "--project", project)
        expect(status.exitstatus).to eq(2)
      end
      expect(Dir.children(project)).to be_empty
    end
  end

  it "does not install ignored Codex guidance when AGENTS.override.md takes precedence" do
    Dir.mktmpdir do |project|
      File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
      File.write(File.join(project, "AGENTS.override.md"), "active team instructions")
      _, stderr, status = cli("install-rules", "--target", "codex", "--project", project)
      expect(status.exitstatus).to eq(2)
      expect(stderr).to include("takes precedence")
      expect(File).not_to exist(File.join(project, "AGENTS.md"))
      expect(File.read(File.join(project, "AGENTS.override.md"))).to eq("active team instructions")
    end
  end

  it "does not displace fallback instructions configured in CODEX_HOME" do
    Dir.mktmpdir do |project|
      Dir.mktmpdir do |codex_home|
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
        File.write(File.join(project, "TEAM_GUIDE.md"), "active team guidance")
        configuration = 'project_doc_fallback_filenames = ["TEAM_GUIDE.md"]'
        File.write(File.join(codex_home, "config.toml"), configuration)
        _, stderr, status = cli("install-rules", "--target", "codex", "--project", project,
                                env: { "CODEX_HOME" => codex_home })
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("fallback", "merge")
        expect(File).not_to exist(File.join(project, "AGENTS.md"))
        expect(File.read(File.join(project, "TEAM_GUIDE.md"))).to eq("active team guidance")
        expect(File.read(File.join(codex_home, "config.toml"))).to eq(configuration)
      end
    end
  end

  %w[project ancestor profile system].each do |layer|
    it "preserves custom instruction discovery from a #{layer} config layer" do
      Dir.mktmpdir do |workspace|
        project = File.join(workspace, "app")
        codex_home = File.join(workspace, "codex-home")
        config = case layer
                 when "project" then File.join(project, ".codex", "config.toml")
                 when "ancestor" then File.join(workspace, ".codex", "config.toml")
                 when "system" then File.join(workspace, "system", "OpenAI", "Codex", "config.toml")
                 else File.join(codex_home, "work.config.toml")
                 end
        FileUtils.mkdir_p([project, File.dirname(config)])
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
        File.write(File.join(project, ".agents.md"), "custom team rules")
        File.write(config, %('project_doc_fallback_filenames' = [\n  ".agents.md"\n]\n))
        _, stderr, status = cli("install-rules", "--target", "codex", "--project", project,
                                env: { "CODEX_HOME" => codex_home, "ProgramData" => File.join(workspace, "system") })
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("fallback", "merge")
        expect(File).not_to exist(File.join(project, "AGENTS.md"))
        expect(File.read(File.join(project, ".agents.md"))).to eq("custom team rules")
      end
    end
  end

  it "allows ordinary Codex settings without changing them or blocking Claude rules" do
    Dir.mktmpdir do |project|
      Dir.mktmpdir do |codex_home|
        File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
        config = File.join(codex_home, "config.toml")
        File.write(config, 'model = "team-model"')
        _, stderr, status = cli("install-rules", "--target", "codex", "--project", project,
                                env: { "CODEX_HOME" => codex_home })
        expect(status.success?).to be(true), stderr
        expect(File.read(config)).to eq('model = "team-model"')
        File.write(config, 'project_doc_fallback_filenames = ["TEAM_GUIDE.md"]')
        _, stderr, status = cli("install-rules", "--target", "claude", "--project", project,
                                env: { "CODEX_HOME" => codex_home })
        expect(status.success?).to be(true), stderr
        expect(File).to exist(File.join(project, ".claude", "rules", "tsurakunai-rails.md"))
      end
    end
  end

  %w[.claude .claude/rules].each do |directory|
    it "does not write rules through a shared #{directory} symlink" do
      Dir.mktmpdir do |project|
        Dir.mktmpdir do |shared|
          File.write(File.join(project, "RAILS_TEAM_POLICY.md"), "team policy")
          destination = File.join(project, directory)
          FileUtils.mkdir_p(File.dirname(destination))
          File.symlink(shared, destination)
          _, stderr, status = cli("install-rules", "--target", "claude", "--project", project)
          expect(status.exitstatus).to eq(2)
          expect(stderr).to include("symlinked instruction directory")
          expect(Dir.children(shared)).to be_empty
          expect(File.readlink(destination)).to eq(shared)
        end
      end
    end
  end

  %w[codex claude].each do |target|
    it "installs the complete #{target} skill and refuses replacement" do
      Dir.mktmpdir do |project|
        stdout, stderr, status = cli("install-skill", "--target", target, "--project", project)
        expect(status.success?).to be(true), stderr
        directory = target == "codex" ? ".agents" : ".claude"
        installed = File.join(project, directory, "skills", "tsurakunai-rails")
        expect(stdout).to include(installed)
        expect(File.read(File.join(installed, "SKILL.md"))).to include("name: tsurakunai-rails")
        expect(File).to exist(File.join(installed, "references", "review.md"))
        %w[tsurakunai-rails-implement tsurakunai-rails-review].each do |name|
          expect(File.read(File.join(project, directory, "skills", name, "SKILL.md"))).to include("name: #{name}")
        end
        _, validation_error, validation_status = Open3.capture3(
          RbConfig.ruby, File.expand_path("../script/validate_skill.rb", __dir__), File.join(project, directory, "skills")
        )
        expect(validation_status.success?).to be(true), validation_error
        skill = File.join(installed, "SKILL.md")
        File.write(skill, "local edits")
        _, stderr, status = cli("install-skill", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists")
        expect(File.read(skill)).to eq("local edits")
      end
    end
  end

  %w[codex claude].each do |target|
    it "does not partially install when a sibling #{target} skill already exists" do
      Dir.mktmpdir do |project|
        directory = target == "codex" ? ".agents" : ".claude"
        parent = File.join(project, directory, "skills")
        existing = File.join(parent, "tsurakunai-rails-review")
        FileUtils.mkdir_p(existing)
        File.write(File.join(existing, "SKILL.md"), "local review instructions")
        _, stderr, status = cli("install-skill", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists")
        expect(Dir.children(parent)).to eq(["tsurakunai-rails-review"])
        expect(File.read(File.join(existing, "SKILL.md"))).to eq("local review instructions")
      end
    end
  end

  it "reports a missing shared reference in an installed skill set" do
    Dir.mktmpdir do |project|
      _, stderr, status = cli("install-skill", "--target", "codex", "--project", project)
      expect(status.success?).to be(true), stderr
      root = File.join(project, ".agents", "skills")
      File.unlink(File.join(root, "tsurakunai-rails", "references", "data.md"))
      _, error, result = Open3.capture3(RbConfig.ruby, File.expand_path("../script/validate_skill.rb", __dir__), root)
      expect(result.exitstatus).to eq(1)
      expect(error).to include("Invalid or missing reference", "data.md")
    end
  end

  it "rejects invalid targets without creating files" do
    Dir.mktmpdir do |project|
      _, _, status = cli("install-skill", "--target", "unknown", "--project", project)
      expect(status.exitstatus).to eq(2)
      expect(Dir.children(project)).to be_empty
    end
  end

  it "requires a test command so a lint-only run cannot pass as full validation" do
    _, stderr, status = cli("check", "--", env: { "RUBYOPT" => "-W0" })
    expect(status.exitstatus).to eq(2)
    expect(stderr).to include("TEST_COMMAND")
  end

  it "runs tests despite failed lint and passes arguments without shell interpretation" do
    Dir.mktmpdir do |project|
      bin = File.join(project, "bin")
      Dir.mkdir(bin)
      bundle = File.join(bin, "bundle")
      File.write(bundle, "#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$LINT_LOG\"\nexit 1\n")
      File.chmod(0o755, bundle)
      log = File.join(project, "lint.log")
      result = File.join(project, "test.txt")
      literal = "$(touch should-not-exist); `touch other-file`"
      stdout, stderr, status = cli("check", "--", RbConfig.ruby, "-e", "File.write(ARGV[0], ARGV[1])", result, literal,
                             chdir: project, env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "LINT_LOG" => log })
      expect(status.exitstatus).to eq(1), stderr
      expect(stdout).to include("Ruby lint: FAIL (exit 1)", "View lint: SKIPPED", "Tests: PASS")
      expect(File.read(log).strip).to eq("exec rubocop --plugin rubocop-tsurakunai-rails")
      expect(File.read(result)).to eq(literal)
      expect(File).not_to exist(File.join(project, "should-not-exist"))
      expect(File).not_to exist(File.join(project, "other-file"))
    end
  end
  [0, 1].each do |test_status|
    it "returns the combined status when lint passes and tests exit #{test_status}" do
      Dir.mktmpdir do |project|
        bin = File.join(project, "bin")
        Dir.mkdir(bin)
        executable = File.join(bin, "bundle")
        File.write(executable, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, executable)
        stdout, _, status = cli("check", "--", RbConfig.ruby, "-e", "exit #{test_status}",
                                env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}" })
        expect(status.exitstatus).to eq(test_status)
        expect(stdout).to include("Ruby lint: PASS", test_status.zero? ? "Tests: PASS" : "Tests: FAIL (exit 1)")
        expect(stdout).to include("Design review still required")
      end
    end
  end

  it "does not interpret a single test command as shell code" do
    Dir.mktmpdir do |project|
      bin = File.join(project, "bin")
      Dir.mkdir(bin)
      executable = File.join(bin, "bundle")
      File.write(executable, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, executable)
      stdout, _, status = cli("check", "--", "touch injected; echo success", chdir: project,
                         env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}" })
      expect(status.exitstatus).to eq(1)
      expect(stdout).to include("Tests: FAIL (could not start command)")
      expect(File).not_to exist(File.join(project, "injected"))
    end
  end

  it "reports a signaled test process as a failed test stage" do
    Dir.mktmpdir do |project|
      bin = File.join(project, "bin")
      Dir.mkdir(bin)
      executable = File.join(bin, "bundle")
      File.write(executable, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, executable)
      stdout, _, status = cli("check", "--", RbConfig.ruby, "-e", "Process.kill('TERM', Process.pid)",
                              env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}" })
      expect(status.exitstatus).to eq(1)
      expect(stdout).to include("Ruby lint: PASS", "Tests: FAIL (signal 15)")
    end
  end

  [[], ["--strict-locals"]].each do |flags|
    it "installs the view profile #{flags.inspect} without overwriting local configuration" do
      Dir.mktmpdir do |project|
        _, stderr, status = cli("install-view-lint", *flags, "--project", project)
        expect(status.success?).to be(true), stderr
        config = File.join(project, ".erb_lint.yml")
        profile = flags.empty? ? "erb_lint.yml" : "erb_lint_strict.yml"
        expect(File.read(config)).to eq(File.read(File.expand_path("../config/#{profile}", __dir__)))
        File.write(config, "local edits")
        _, stderr, status = cli("install-view-lint", "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists")
        expect(File.read(config)).to eq("local edits")
      end
    end
  end

  it "preserves an existing custom loader without installing a partial configuration" do
    Dir.mktmpdir do |project|
      directory = File.join(project, ".erb_linters")
      Dir.mkdir(directory)
      loader = File.join(directory, "tsurakunai_partial_inputs.rb")
      File.write(loader, "local edits")
      _, stderr, status = cli("install-view-lint", "--project", project)
      expect(status.exitstatus).to eq(2)
      expect(stderr).to include("Already exists")
      expect(File.read(loader)).to eq("local edits")
      expect(File).not_to exist(File.join(project, ".erb_lint.yml"))
    end
  end

  it "reports missing view configuration while still running the test command" do
    Dir.mktmpdir do |project|
      bin = File.join(project, "bin")
      Dir.mkdir(bin)
      File.write(File.join(bin, "bundle"), "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, File.join(bin, "bundle"))
      result = File.join(project, "test.txt")
      _, stderr, status = cli("check", "--views", "--", RbConfig.ruby, "-e", "File.write(ARGV[0], 'ran')", result,
                             chdir: project, env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}" })
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include("install-view-lint")
      expect(File.read(result)).to eq("ran")
    end
  end

  [0, 1].each do |view_status|
    it "combines view lint status #{view_status} with Ruby lint and runs tests" do
      Dir.mktmpdir do |project|
        bin = File.join(project, "bin")
        Dir.mkdir(bin)
        log = File.join(project, "lint.log")
        File.write(File.join(project, ".erb_lint.yml"), "EnableDefaultLinters: false")
        File.write(File.join(bin, "bundle"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$LINT_LOG\"\nif [ \"$2\" = erb_lint ]; then exit #{view_status}; fi\nexit 0\n")
        File.chmod(0o755, File.join(bin, "bundle"))
        result = File.join(project, "test.txt")
        _, _, status = cli("check", "--views", "--", RbConfig.ruby, "-e", "File.write(ARGV[0], 'ran')", result,
                           chdir: project, env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "LINT_LOG" => log })
        expect(status.exitstatus).to eq(view_status)
        expect(File.read(log)).to include("exec rubocop --plugin rubocop-tsurakunai-rails", "exec erb_lint --lint-all")
        expect(File.read(result)).to eq("ran")
      end
    end
  end

end
