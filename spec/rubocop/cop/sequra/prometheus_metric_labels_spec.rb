require "spec_helper"

RSpec.describe RuboCop::Cop::Sequra::PrometheusMetricLabels, :config do
  # Consumer repos are all on Ruby 3.2+, and real call sites use hash
  # shorthand (`{ region:, outcome: }`), which RuboCop's default
  # target of 2.7 cannot parse.
  let(:ruby_version) { 3.4 }

  let(:config) do
    RuboCop::Config.new(
      "Sequra/PrometheusMetricLabels" => {
        "Enabled" => true,
      }
    )
  end

  context "with a `labels:` keyword" do
    it "flags increment" do
      expect_offense(<<~RUBY)
        counter.increment(labels: { outcome: :bound })
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        counter.increment({ outcome: :bound })
      RUBY
    end

    it "flags decrement" do
      expect_offense(<<~RUBY)
        gauge.decrement(labels: { outcome: :bound })
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        gauge.decrement({ outcome: :bound })
      RUBY
    end

    it "flags observe" do
      expect_offense(<<~RUBY)
        histogram.observe(duration, labels: { outcome: :ok })
                                    ^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        histogram.observe(duration, { outcome: :ok })
      RUBY
    end

    it "flags an explicitly braced hash, which parses identically" do
      expect_offense(<<~RUBY)
        counter.increment({ labels: { outcome: :bound } })
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        counter.increment({ outcome: :bound })
      RUBY
    end

    it "flags a variable passed under the keyword" do
      expect_offense(<<~RUBY)
        counter.increment(labels: metric_labels)
                          ^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        counter.increment(metric_labels)
      RUBY
    end

    it "flags a chained receiver" do
      expect_offense(<<~RUBY)
        Metrics.instance.request_counter.increment(labels: { outcome: :bound })
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        Metrics.instance.request_counter.increment({ outcome: :bound })
      RUBY
    end

    it "flags a call site using hash shorthand values" do
      expect_offense(<<~RUBY)
        Metrics.instance.request_counter.increment(labels: { region:, outcome: })
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_correction(<<~RUBY)
        Metrics.instance.request_counter.increment({ region:, outcome: })
      RUBY
    end

    it "flags but does not autocorrect when the keyword has siblings" do
      expect_offense(<<~RUBY)
        counter.increment(labels: { outcome: :bound }, by: 2)
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LABELS_KEYWORD}
      RUBY

      expect_no_corrections
    end
  end

  context "with flipped positional arguments" do
    it "flags a labels hash in observe's value position" do
      expect_offense(<<~RUBY)
        histogram.observe({ outcome: :ok }, duration)
                          ^^^^^^^^^^^^^^^^ #{described_class::MSG_VALUE_FIRST}
      RUBY
    end

    it "flags a braced hash as observe's only argument" do
      expect_offense(<<~RUBY)
        histogram.observe({ outcome: :ok })
                          ^^^^^^^^^^^^^^^^ #{described_class::MSG_VALUE_FIRST}
      RUBY
    end

    it "flags a value before the labels on increment" do
      expect_offense(<<~RUBY)
        counter.increment(1, { outcome: :bound })
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(described_class::MSG_LABELS_FIRST, method: :increment)}
      RUBY
    end

    it "flags a value before the labels on decrement" do
      expect_offense(<<~RUBY)
        gauge.decrement(2, { outcome: :bound })
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(described_class::MSG_LABELS_FIRST, method: :decrement)}
      RUBY
    end
  end

  context "with stubbed metric expectations" do
    it "flags a `labels:` keyword on a message expectation" do
      expect_offense(<<~RUBY)
        expect(counter).to receive(:increment).with(labels: { region: "eu" })
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_STUBBED_LABELS}
      RUBY

      expect_correction(<<~RUBY)
        expect(counter).to receive(:increment).with({ region: "eu" })
      RUBY
    end

    it "flags a `labels:` keyword on a spy assertion" do
      expect_offense(<<~RUBY)
        expect(counter).to have_received(:observe).with(labels: { outcome: :ok })
                                                        ^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_STUBBED_LABELS}
      RUBY

      expect_correction(<<~RUBY)
        expect(counter).to have_received(:observe).with({ outcome: :ok })
      RUBY
    end

    it "flags a stub set up with allow" do
      expect_offense(<<~RUBY)
        allow(counter).to receive(:decrement).with(labels: { outcome: :bound })
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_STUBBED_LABELS}
      RUBY

      expect_correction(<<~RUBY)
        allow(counter).to receive(:decrement).with({ outcome: :bound })
      RUBY
    end
  end

  context "with correct usage" do
    it "accepts labels passed positionally" do
      expect_no_offenses(<<~RUBY)
        counter.increment({ outcome: :bound })
      RUBY
    end

    it "accepts a braceless positional labels hash" do
      expect_no_offenses(<<~RUBY)
        counter.increment(outcome: :bound, region: "eu")
      RUBY
    end

    it "accepts shorthand label values" do
      expect_no_offenses(<<~RUBY)
        counter.increment({ region:, outcome: })
      RUBY
    end

    it "accepts labels then value on increment" do
      expect_no_offenses(<<~RUBY)
        counter.increment({ outcome: :bound }, 2)
      RUBY
    end

    it "accepts value then labels on observe" do
      expect_no_offenses(<<~RUBY)
        histogram.observe(duration, { outcome: :ok })
      RUBY
    end

    it "accepts observe with no labels" do
      expect_no_offenses(<<~RUBY)
        histogram.observe(Time.current - started_at)
      RUBY
    end

    it "accepts increment with no arguments" do
      expect_no_offenses(<<~RUBY)
        counter.increment
      RUBY
    end

    it "accepts a positional labels variable" do
      expect_no_offenses(<<~RUBY)
        counter.increment(metric_labels)
      RUBY
    end

    it "accepts an unrelated label named similarly" do
      expect_no_offenses(<<~RUBY)
        counter.increment({ label_set: :bound })
      RUBY
    end

    it "accepts a message expectation on the positional hash" do
      expect_no_offenses(<<~RUBY)
        expect(counter).to receive(:increment).with({ region: "eu" })
      RUBY
    end

    it "accepts a bare message expectation" do
      expect_no_offenses(<<~RUBY)
        expect(counter).to receive(:increment)
      RUBY
    end
  end

  context "with non-metric receivers" do
    it "accepts Rails cache increment with options" do
      expect_no_offenses(<<~RUBY)
        Rails.cache.increment(new_session_count_key, 1, expires_in: TTL)
      RUBY
    end

    it "accepts Rails cache increment without an explicit amount" do
      expect_no_offenses(<<~RUBY)
        Rails.cache.increment(key, expires_in: TTL)
      RUBY
    end

    it "accepts an atomic counter increment" do
      expect_no_offenses(<<~RUBY)
        atomic_counter.increment(5)
      RUBY
    end

    it "accepts a method definition named increment" do
      expect_no_offenses(<<~RUBY)
        def self.increment(labels)
          labels
        end
      RUBY
    end

    it "accepts an unrelated method taking a labels keyword" do
      expect_no_offenses(<<~RUBY)
        chart.render(labels: { outcome: :bound })
      RUBY
    end

    it "accepts a wrapper whose observe takes keyword arguments" do
      expect_no_offenses(<<~RUBY)
        Instrumentation::CardholderNameMatchHistogram.new.observe(
          score: result.score,
          match: result.match,
          reason: result.reason
        )
      RUBY
    end

    it "accepts a wrapper observe call using hash shorthand" do
      expect_no_offenses(<<~RUBY)
        histogram_wrapper.observe(score:, match:, reason:)
      RUBY
    end

    it "accepts a wrapper observe definition delegating positionally" do
      expect_no_offenses(<<~RUBY)
        def observe(score:, match:, reason:)
          histogram.observe(score, { match:, reason: })
        end
      RUBY
    end
  end
end
