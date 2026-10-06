# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::ImplicitContext do
  let(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new("TsurakunaiRails/ImplicitContext" => { "AllowedConstants" => ["Electric::Current"] }) }

  it "rejects implicit global context including constant references and safe navigation" do
    expect_offense(<<~RUBY)
      Current.user
      ^^^^^^^ #{described_class::MSG}
      ::Current&.account
      ^^^^^^^^^ #{described_class::MSG}
      Billing::Current.user
      ^^^^^^^^^^^^^^^^ #{described_class::MSG}
      context = Current
                ^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "allows explicit inputs, unrelated names, declarations and approved business constants" do
    expect_no_offenses(<<~RUBY)
      def confirm!(actor:)
        actor.id
      end
      CurrentValue.new
      Electric::Current.measure
      class Current < ActiveSupport::CurrentAttributes
        attribute :user
      end
    RUBY
  end
end
