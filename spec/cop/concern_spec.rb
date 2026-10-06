# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::Concern do
  let(:cop) { described_class.new }

  it "detects explicit business Concern declarations" do
    expect_offense(<<~RUBY)
      module Billable
        extend ActiveSupport::Concern
               ^^^^^^^^^^^^^^^^^^^^^^ #{described_class.cop_name}: #{described_class::MSG}
        self.include ::ActiveSupport::Concern
                     ^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class.cop_name}: #{described_class::MSG}
      end
    RUBY
  end

  it "leaves framework extensions and explicit collaboration to semantic review" do
    expect_no_offenses(<<~RUBY)
      include ActiveModel::Model
      calculator = InvoiceTotal.new(items: items)
      calculator.call
      registry.extend(ActiveSupport::Concern)
    RUBY
  end
end
