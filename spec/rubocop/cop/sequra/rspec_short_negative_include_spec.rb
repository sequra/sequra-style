# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::RSpecShortNegativeInclude, :config do
  let(:config) do
    RuboCop::Config.new(
      "Sequra/RSpecShortNegativeInclude" => {
        "Enabled" => true,
      }
    )
  end

  it "flags a short number asserted absent" do
    expect_offense(<<~RUBY)
      expect(body).not_to include("930", "800 180 501")
                                  ^^^^^ #{described_class::MSG}
    RUBY
  end

  it "flags a short word asserted absent with to_not" do
    expect_offense(<<~RUBY)
      expect(body).to_not include("RU")
                                  ^^^^ #{described_class::MSG}
    RUBY
  end

  it "flags an id asserted absent" do
    expect_offense(<<~RUBY)
      expect(result.error[:message]).not_to include(shopper_user.id.to_s)
                                                    ^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "accepts a string with punctuation or spaces" do
    expect_no_offenses(<<~RUBY)
      expect(body).not_to include("49,99", "930 47 71 61")
    RUBY
  end

  it "accepts a long string" do
    expect_no_offenses(<<~RUBY)
      expect(body).not_to include("translation")
    RUBY
  end

  it "accepts a short string asserted present" do
    expect_no_offenses(<<~RUBY)
      expect(body).to include("930")
    RUBY
  end
end
