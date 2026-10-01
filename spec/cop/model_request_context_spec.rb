# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::ModelRequestContext do
  let(:config) { RuboCop::Config.new("TsurakunaiRails/ModelRequestContext" => { "AllowedMethods" => [] }) }
  let(:cop) { described_class.new(config) }

  %w[params session cookies flash request response current_user current_account].each do |method|
    it "detects the implicit #{method} controller helper" do
      expect_offense(<<~RUBY)
        #{method}
        #{'^' * method.length} #{described_class::MSG}
      RUBY
    end
  end

  it "detects an explicit self call" do
    expect_offense(<<~RUBY)
      self.params[:memo]
           ^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "detects safe navigation on self" do
    expect_offense(<<~RUBY)
      self&.current_user
            ^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "accepts local arguments, explicit values, and an unrelated receiver" do
    expect_no_offenses(<<~RUBY)
      def change_memo(params, current_user)
        memo = params.fetch(:memo)
        owner_id = current_user.id
        payload.params
      end
    RUBY
  end

  context "when request is a documented domain attribute" do
    let(:config) { RuboCop::Config.new("TsurakunaiRails/ModelRequestContext" => { "AllowedMethods" => ["request"] }) }

    it "allows only the configured domain name" do
      expect_no_offenses("request.fetch(:reference)")
      expect_offense(<<~RUBY)
        current_user.id
        ^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end
end
