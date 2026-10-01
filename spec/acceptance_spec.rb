# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "Rails consumer acceptance" do
  it "accepts ordinary Rails code and detects six concrete regressions through the public harness" do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.expand_path("../script/acceptance.rb", __dir__))
    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
    expect(stdout).to include("PASS healthy")
    expect(stdout.scan(/^PASS regression /).length).to eq(6)
  end
end
