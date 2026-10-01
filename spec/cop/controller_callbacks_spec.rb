# frozen_string_literal: true

RSpec.describe RuboCop::Cop::TsurakunaiRails::ControllerCallbacks do
  let(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new("TsurakunaiRails/ControllerCallbacks" => { "AllowedMethods" => [] }) }

  %i[before_action after_action around_action append_before_action append_after_action append_around_action
      prepend_before_action prepend_after_action prepend_around_action before_filter after_filter around_filter
      append_before_filter append_after_filter append_around_filter prepend_before_filter prepend_after_filter
      prepend_around_filter].each do |method|
    it "detects #{method} registrations" do
      expect_offense(<<~RUBY)
        #{method} :load_invoice
        #{'^' * method.length} #{described_class::MSG}
      RUBY
    end
  end

  it "detects explicit self and inline blocks" do
    expect_offense(<<~RUBY)
      self.after_action { audit }
           ^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "does not mistake another object's method for a registration" do
    expect_no_offenses("workflow.before_action(:load_invoice)")
  end

  context "with a framework exception" do
    let(:config) { RuboCop::Config.new("TsurakunaiRails/ControllerCallbacks" => { "AllowedMethods" => ["authenticate_user!"] }) }

    it "allows symbol and string names with options" do
      expect_no_offenses(<<~RUBY)
        before_action :authenticate_user!, only: :show
        before_action "authenticate_user!"
      RUBY
    end

    it "rejects mixed registrations" do
      expect_offense(<<~RUBY)
        before_action :authenticate_user!, :load_invoice
        ^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "rejects dynamic registrations" do
      expect_offense(<<~RUBY)
        before_action callback_name
        ^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "rejects a block even with an allowed argument" do
      expect_offense(<<~RUBY)
        before_action(:authenticate_user!) { load_invoice }
        ^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end
end
