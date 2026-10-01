# frozen_string_literal: true

require "tsurakunai/rails/cli"
require "tmpdir"
require "open3"
require "rbconfig"

RSpec.describe Tsurakunai::Rails::CLI do
  def cli(*arguments, env: {}, **options)
    Open3.capture3(env, RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
                  File.expand_path("../exe/tsurakunai-rails", __dir__), *arguments, **options)
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
