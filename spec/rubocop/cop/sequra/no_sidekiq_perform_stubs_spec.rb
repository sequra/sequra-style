require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::NoSidekiqPerformStubs, :config do
  let(:config) do
    RuboCop::Config.new(
      "Sequra/NoSidekiqPerformStubs" => {
        "Enabled" => true,
      }
    )
  end

  context "with `allow(...).to receive(...)` stubs" do
    it "flags bare perform_async" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_async)
                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags perform_at" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_at)
                          ^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags perform_in" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_in)
                          ^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags with chained `.and_return`" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_async).and_return("jid")
                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags with chained `.and_raise`" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_async).and_raise(StandardError)
                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags with chained `.with(args)`" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_async).with(123)
                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags with chained `.with(args).and_return`" do
      expect_offense(<<~RUBY)
        allow(SomeJob).to receive(:perform_async).with(123).and_return("jid")
                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags namespaced job classes" do
      expect_offense(<<~RUBY)
        allow(MyPack::SomeJob).to receive(:perform_async)
                                  ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end

  context "with `expect(...).to receive(...)` stubs" do
    it "flags positive expectation" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to receive(:perform_async)
                           ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags negative expectation with `not_to`" do
      expect_offense(<<~RUBY)
        expect(SomeJob).not_to receive(:perform_async)
                               ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags negative expectation with `to_not`" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to_not receive(:perform_at)
                               ^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags expectation with count constraint" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to receive(:perform_async).exactly(2).times
                           ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end

  context "with `have_received` spy assertions" do
    it "flags positive spy on perform_async" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to have_received(:perform_async)
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags negative spy with `not_to`" do
      expect_offense(<<~RUBY)
        expect(SomeJob).not_to have_received(:perform_async)
                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags spy with `.with(args)`" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to have_received(:perform_at).with(time, data)
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags spy with `.twice` count constraint" do
      expect_offense(<<~RUBY)
        expect(SomeJob).to have_received(:perform_async).twice
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end

  context "with `allow_any_instance_of` / `expect_any_instance_of`" do
    it "flags allow_any_instance_of with perform_async" do
      expect_offense(<<~RUBY)
        allow_any_instance_of(SomeJob).to receive(:perform_async)
                                          ^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end

    it "flags expect_any_instance_of with perform_in" do
      expect_offense(<<~RUBY)
        expect_any_instance_of(SomeJob).to receive(:perform_in)
                                           ^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
      RUBY
    end
  end

  context "with `.and_call_original` escape hatch" do
    it "does not flag `receive(:perform_async).and_call_original`" do
      expect_no_offenses(<<~RUBY)
        expect(SomeJob).to receive(:perform_async).and_call_original
      RUBY
    end

    it "does not flag `receive(:perform_at).and_call_original`" do
      expect_no_offenses(<<~RUBY)
        allow(SomeJob).to receive(:perform_at).and_call_original
      RUBY
    end

    it "does not flag `receive(:perform_async).with(args).and_call_original`" do
      expect_no_offenses(<<~RUBY)
        expect(SomeJob).to receive(:perform_async).with(123).and_call_original
      RUBY
    end

    it "does not flag long chains ending in `.and_call_original`" do
      expect_no_offenses(<<~RUBY)
        expect(SomeJob).to receive(:perform_async).with(123).once.ordered.and_call_original
      RUBY
    end
  end

  context "with correct enqueue assertions" do
    it "does not flag `have_enqueued_sidekiq_job`" do
      expect_no_offenses(<<~RUBY)
        expect(SomeJob).to have_enqueued_sidekiq_job(123, name: "value")
      RUBY
    end

    it "does not flag `change(Job.jobs, :size)`" do
      expect_no_offenses(<<~RUBY)
        expect { subject }.to change(SomeJob.jobs, :size).by(1)
      RUBY
    end

    it "does not flag direct queue inspection" do
      expect_no_offenses(<<~RUBY)
        expect(SomeJob.jobs.last["args"]).to eq([123, "name"])
      RUBY
    end

    it "does not flag `Sidekiq::Worker.drain_all`" do
      expect_no_offenses(<<~RUBY)
        Sidekiq::Worker.drain_all
      RUBY
    end
  end

  context "with unrelated stubs" do
    it "does not flag stubs on other methods" do
      expect_no_offenses(<<~RUBY)
        allow(SomeService).to receive(:call).and_return(true)
      RUBY
    end

    it "does not flag stubs on methods named like perform but not the enqueue API" do
      expect_no_offenses(<<~RUBY)
        allow(SomeJob).to receive(:perform).and_return(nil)
      RUBY
    end

    it "does not flag spies on other methods" do
      expect_no_offenses(<<~RUBY)
        expect(SomeService).to have_received(:call).with(123)
      RUBY
    end
  end

  context "when the symbol matches as a partial / different argument" do
    it "does not flag `receive` with a different symbol that contains 'perform'" do
      expect_no_offenses(<<~RUBY)
        allow(SomeJob).to receive(:perform).with(123)
      RUBY
    end

    it "does not flag string method names (RSpec accepts strings but rare)" do
      expect_no_offenses(<<~RUBY)
        allow(SomeJob).to receive("perform_async")
      RUBY
    end
  end
end
