require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::NoHelpers, :config do
  let(:config) do
    RuboCop::Config.new(
      "Sequra/NoHelpers" => {
        "Enabled" => true,
      }
    )
  end

  context "when the file lives under app/helpers" do
    it "flags a module" do
      expect_offense(<<~RUBY, "app/helpers/orders_helper.rb")
        module OrdersHelper
        ^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
          def label(order)
            order.reference
          end
        end
      RUBY
    end

    it "flags a class" do
      expect_offense(<<~RUBY, "app/helpers/orders_helper.rb")
        class OrdersHelper
        ^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
        end
      RUBY
    end

    it "flags a nested module" do
      expect_offense(<<~RUBY, "app/helpers/admin/orders_helper.rb")
        module Admin
        ^^^^^^^^^^^^ #{described_class::MSG}
          module OrdersHelper
          ^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
          end
        end
      RUBY
    end
  end

  context "when the file lives under a pack's app/helpers" do
    it "flags a module" do
      expect_offense(<<~RUBY, "packs/my_pack/app/helpers/orders_helper.rb")
        module OrdersHelper
        ^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
        end
      RUBY
    end

    it "flags a module in a nested pack" do
      expect_offense(<<~RUBY, "domains/billing/packs/my_pack/app/helpers/orders_helper.rb")
        module OrdersHelper
        ^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
        end
      RUBY
    end
  end

  context "when the file lives outside app/helpers" do
    it "accepts a presenter" do
      expect_no_offenses(<<~RUBY, "app/presenters/order_presenter.rb")
        class OrderPresenter
        end
      RUBY
    end

    it "accepts a class whose name merely ends in Helper" do
      expect_no_offenses(<<~RUBY, "app/services/routing_helper.rb")
        class RoutingHelper
        end
      RUBY
    end

    it "accepts a directory that merely starts with helpers" do
      expect_no_offenses(<<~RUBY, "app/helpers_registry/order_registry.rb")
        module OrderRegistry
        end
      RUBY
    end
  end

  it "highlights the declaration only, not the body" do
    processed = RuboCop::ProcessedSource.new(
      "module OrdersHelper\n  def label = nil\nend\n",
      RUBY_VERSION.to_f,
      "app/helpers/orders_helper.rb"
    )
    offenses = RuboCop::Cop::Commissioner.new([described_class.new]).investigate(processed).offenses

    expect(offenses.size).to eq(1)
    expect(offenses.first.location.source).to eq("module OrdersHelper")
  end
end
