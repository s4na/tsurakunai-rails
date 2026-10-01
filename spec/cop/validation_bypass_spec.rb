# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::ValidationBypass do
  let(:config) { RuboCop::Config.new("TsurakunaiRails/ValidationBypass" => {}) }
  let(:cop) { described_class.new(config) }
  %i[update_attribute update_attribute! update_column update_columns].each do |method|
    it "detects #{method}" do
      expect_offense(<<~RUBY)
        record.#{method}(:status, "done")
               #{'^' * method.length} #{described_class::MSG}
      RUBY
    end
  end

  %w[save save!].each do |method|
    it "detects #{method}(validate: false)" do
      expect_offense(<<~RUBY)
        record.#{method}(validate: false, touch: false)
               #{'^' * method.length} #{described_class::MSG}
      RUBY
    end
  end

  it "detects safe navigation" do
    expect_offense(<<~RUBY)
      record&.update_columns(status: "done")
              ^^^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "allows validated writes and leaves dynamic options for review" do
    expect_no_offenses(<<~RUBY)
      record.update!(status: "done")
      record.save(validate: true)
      record.save
      record.save!(**options)
    RUBY
  end
end
