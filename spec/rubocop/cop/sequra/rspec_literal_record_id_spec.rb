# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::RSpecLiteralRecordId, :config do
  let(:config) do
    RuboCop::Config.new(
      "Sequra/RSpecLiteralRecordId" => {
        "Enabled" => true,
      }
    )
  end

  it "flags a literal id on create" do
    expect_offense(<<~RUBY)
      create(:shopper_user, id: 4211)
                            ^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "flags a literal id among other attributes" do
    expect_offense(<<~RUBY)
      create(:shopper_user, :without_orders, name: "Ana", id: 5377)
                                                          ^^^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "flags a literal id on FactoryBot.create" do
    expect_offense(<<~RUBY)
      FactoryBot.create(:shopping_category, id: 88)
                                            ^^^^^^ #{described_class::MSG}
    RUBY
  end

  it "flags a literal id on create_list" do
    expect_offense(<<~RUBY)
      create_list(:order, 2, id: 1)
                             ^^^^^ #{described_class::MSG}
    RUBY
  end

  it "accepts a created record without an id" do
    expect_no_offenses(<<~RUBY)
      create(:shopper_user, :without_orders)
    RUBY
  end

  it "accepts an id taken from another record" do
    expect_no_offenses(<<~RUBY)
      create(:order, shopper_user_id: shopper_user.id)
    RUBY
  end

  it "accepts a literal id on build, which never saves a row" do
    expect_no_offenses(<<~RUBY)
      build(:order, id: 1)
      build_stubbed(:order, id: 1)
    RUBY
  end

  it "accepts a literal id on a method that is not a factory" do
    expect_no_offenses(<<~RUBY)
      described_class.create(id: 1)
    RUBY
  end
end
