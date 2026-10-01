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
        skill = File.join(installed, "SKILL.md")
        File.write(skill, "local edits")
        _, stderr, status = cli("install-skill", "--target", target, "--project", project)
        expect(status.exitstatus).to eq(2)
        expect(stderr).to include("Already exists")
        expect(File.read(skill)).to eq("local edits")
      end
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
      _, stderr, status = cli("check", "--", RbConfig.ruby, "-e", "File.write(ARGV[0], ARGV[1])", result, literal,
                             chdir: project, env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}", "LINT_LOG" => log })
      expect(status.exitstatus).to eq(1), stderr
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
      _, _, status = cli("check", "--", "touch injected; echo success", chdir: project,
                         env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}" })
      expect(status.exitstatus).to eq(1)
      expect(File).not_to exist(File.join(project, "injected"))
    end
  end

end
