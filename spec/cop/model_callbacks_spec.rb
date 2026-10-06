# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::ModelCallbacks do
  let(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new("TsurakunaiRails/ModelCallbacks" => { "AllowedCallbacks" => { "before_validation" => ["normalize_email"] } }) }

  %i[before_save around_save after_save before_create around_create after_create before_update
     around_update after_update before_destroy around_destroy after_destroy after_initialize
     after_find after_touch before_commit after_commit after_rollback after_save_commit after_create_commit
     after_update_commit after_destroy_commit after_validation].each do |method|
    it "rejects implicit #{method} business steps" do
      expect_offense(<<~RUBY)
        #{method} :collect_payment
        #{'^' * method.length} #{described_class::MSG}
      RUBY
    end
  end

  it "accepts the approved normalization and explicit transaction callbacks" do
    expect_no_offenses(<<~RUBY)
      before_validation :normalize_email, on: :create
      self.before_validation "normalize_email"
      transaction.before_commit { record_audit }
      transaction.after_commit { notify }
      validates :email, presence: true
    RUBY
  end

  it "does not approve the same method under a different lifecycle" do
    expect_offense(<<~RUBY)
      after_save :normalize_email
      ^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "rejects mixed, block and dynamic registration including set_callback" do
    expect_offense(<<~RUBY)
      before_validation :normalize_email, :collect_payment
      ^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      before_validation(:normalize_email) { collect_payment }
      ^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      before_validation callback_name
      ^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      self.set_callback :save, :after, :collect_payment
           ^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end
end
