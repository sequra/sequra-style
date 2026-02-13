require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::AsyncJobPattern, :config do
  let(:config) do
    RuboCop::Config.new(
      "Sequra/AsyncJobPattern" => {
        "Enabled" => true,
      }
    )
  end

  context "when class inherits from ApplicationJob" do
    context "with no operation call" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class MyJob < ApplicationJob
                ^^^^^ Sidekiq job should delegate to exactly one Operation
            def perform(id)
              user = User.find(id)
              user.update!(status: :active)
            end
          end
        RUBY
      end
    end

    context "with exactly one operation call" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end
    end

    context "with multiple operation calls" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class MyJob < ApplicationJob
                ^^^^^ Sidekiq job should delegate to exactly one Operation
            def perform(id, type)
              if type == :a
                OperationA.call(id: id)
              else
                OperationB.call(id: id)
              end
            end
          end
        RUBY
      end
    end

    context "with namespaced operation" do
      it "does not register an offense for single namespaced operation" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            def perform(id)
              Payments::RefundOperation.call(id: id)
            end
          end
        RUBY
      end
    end

    context "with dynamic operation call" do
      it "registers an offense (known limitation - dynamic calls not detected)" do
        expect_offense(<<~RUBY)
          class MyJob < ApplicationJob
                ^^^^^ Sidekiq job should delegate to exactly one Operation
            def perform(operation_class, id)
              operation_class.call(id: id)
            end
          end
        RUBY
      end
    end

    context "with non-Operation class call" do
      it "registers an offense for MyService.call" do
        expect_offense(<<~RUBY)
          class MyJob < ApplicationJob
                ^^^^^ Sidekiq job should delegate to exactly one Operation
            def perform(id)
              MyService.call(id: id)
            end
          end
        RUBY
      end
    end
  end

  context "when class includes Sidekiq::Worker" do
    context "with no operation call" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class MyWorker
                ^^^^^^^^ Sidekiq job should delegate to exactly one Operation
            include Sidekiq::Worker

            def perform(id)
              user = User.find(id)
              user.update!(status: :active)
            end
          end
        RUBY
      end
    end

    context "with exactly one operation call" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyWorker
            include Sidekiq::Worker

            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end
    end
  end

  context "when class includes Sidekiq::Job" do
    context "with no operation call" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class MyWorker
                ^^^^^^^^ Sidekiq job should delegate to exactly one Operation
            include Sidekiq::Job

            def perform(id)
              user = User.find(id)
              user.update!(status: :active)
            end
          end
        RUBY
      end
    end
  end

  context "when class is not a Sidekiq job" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyService
          def call(id)
            user = User.find(id)
            user.update!(status: :active)
          end
        end
      RUBY
    end

    it "does not register an offense for regular class with operation call" do
      expect_no_offenses(<<~RUBY)
        class MyService
          def call(id)
            MyOperation.call(id: id)
            AnotherOperation.call(id: id)
          end
        end
      RUBY
    end
  end

  context "with class length validation" do
    let(:class_length_message) do
      "Job has too much logic to be a simple Operation delegate. Consider moving logic into the Operation"
    end

    context "when class exceeds max length (10 lines)" do
      it "registers an offense for class length" do
        expect_offense(<<~RUBY, message: class_length_message)
          class MyJob < ApplicationJob
          ^^^^^ %{message}
            def perform(id)
              MyOperation.call(id: id)
            end

            def something_else
              line1
              line2
              line3
              line4
              line5
              line6
              line7
            end
          end
        RUBY
      end
    end

    context "when class is within max length" do
      it "does not register a class length offense" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end
    end

    context "when counting multiline constructs as one line" do
      it "counts multiline arrays as one line" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            ITEMS = [
              :one,
              :two,
              :three,
              :four,
              :five
            ]

            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end

      it "counts multiline hashes as one line" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            OPTIONS = {
              one: 1,
              two: 2,
              three: 3,
              four: 4,
              five: 5
            }

            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end

      it "counts nested multiline constructs correctly" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            ITEMS = [
              { a: 1, b: 2 },
              { c: 3, d: 4 },
              { e: 5, f: 6 },
              { g: 7, h: 8 }
            ]

            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end

      it "excludes sidekiq_retry_in block from line count" do
        expect_no_offenses(<<~RUBY)
          class MyJob < ApplicationJob
            sidekiq_retry_in do |_count, exception|
              case exception
              when ActiveRecord::Deadlocked
                10.minutes.seconds.to_i
              else
                :kill
              end
            end

            def perform(id)
              MyOperation.call(id: id)
            end
          end
        RUBY
      end
    end
  end

  context "when both offenses occur" do
    let(:class_length_message) do
      "Job has too much logic to be a simple Operation delegate. Consider moving logic into the Operation"
    end

    it "registers both offenses" do
      expect_offense(<<~RUBY, message: class_length_message)
        class MyJob < ApplicationJob
        ^^^^^ %{message}
              ^^^^^ Sidekiq job should delegate to exactly one Operation
          def perform(id)
            user = User.find(id)
            user.update!(status: :active)
          end

          def something_else
            line1
            line2
            line3
            line4
            line5
            line6
            line7
          end
        end
      RUBY
    end
  end
end
