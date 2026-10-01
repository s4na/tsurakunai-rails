# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::DefaultScope do
  let(:config) { RuboCop::Config.new("TsurakunaiRails/DefaultScope" => {}) }
  let(:cop) { described_class.new(config) }
  it "detects a block" do
    expect_offense(<<~RUBY)
      default_scope { where(active: true) }
      ^^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "detects explicit self and lambda syntax" do
    expect_offense(<<~RUBY)
      self.default_scope -> { order(:id) }
           ^^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "allows explicit named scopes and unrelated receivers" do
    expect_no_offenses(<<~RUBY)
      scope :active, -> { where(active: true) }
      query.default_scope
    RUBY
  end
  it "detects safe navigation on self" do
    expect_offense(<<~RUBY)
      self&.default_scope { all }
            ^^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

end
