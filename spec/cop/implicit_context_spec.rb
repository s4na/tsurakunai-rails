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

  it "allows approved constants in their lexical module and nested class" do
    expect_no_offenses(<<~RUBY)
      module Electric
        Current.measure
        class Circuit
          def measure
            Current.measure
          end
        end
      end
    RUBY
  end

  it "does not extend namespace permission to absolute, unrelated or compact outer references" do
    expect_offense(<<~RUBY)
      module Electric
        ::Current.user
        ^^^^^^^^^ #{described_class::MSG}
      end
      module Billing
        Current.user
        ^^^^^^^ #{described_class::MSG}
      end
      module Electric::Tools
        Current.user
        ^^^^^^^ #{described_class::MSG}
      end
    RUBY
  end

  it "uses the absolute namespace when a module is reopened inside another module" do
    expect_no_offenses(<<~RUBY)
      module Billing
        module ::Electric
          Current.measure
        end
      end
    RUBY
  end

  it "does not treat a superclass expression as inside the class namespace" do
    expect_offense(<<~RUBY)
      class Electric < Current
                       ^^^^^^^ #{described_class::MSG}
      end
    RUBY
  end
end
