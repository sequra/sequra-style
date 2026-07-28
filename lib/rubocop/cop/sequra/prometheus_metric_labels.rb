module RuboCop
  module Cop
    module Sequra
      # Detects malformed label arguments on `prometheus_exporter` metric calls.
      #
      # `PrometheusExporter::Client::RemoteMetric` takes labels as a positional
      # hash, and the position differs per method:
      #
      #   increment(keys = nil, value = 1)
      #   decrement(keys = nil, value = 1)
      #   observe(value = 1, keys = nil)
      #
      # None of them accept keyword arguments, so `increment(labels: {...})`
      # does not raise. Ruby folds the keyword into the positional `keys` hash
      # and the exporter emits a series carrying a label literally named
      # `labels`, whose value is the stringified inner hash. The result is
      # valid Prometheus exposition text, so the scrape succeeds and the
      # target stays healthy — `sum by (outcome)` simply never matches.
      #
      # Nothing downstream can catch it: the exporter keys its series by the
      # raw hash, `labels_text` interpolates label names without validating
      # them, and `opts: { labels: [...] }` at registration is discarded
      # outright for counters and gauges. There is no label schema anywhere,
      # so a wrong label name is indistinguishable from a new one, and the
      # mistake only surfaces when a query silently returns nothing.
      #
      # @example
      #   # bad - folded into a label named "labels"
      #   counter.increment(labels: { outcome: :bound })
      #
      #   # good
      #   counter.increment({ outcome: :bound })
      #
      #   # bad - observe takes the value first
      #   histogram.observe({ outcome: :ok }, duration)
      #
      #   # good
      #   histogram.observe(duration, { outcome: :ok })
      #
      #   # bad - increment takes the labels first
      #   counter.increment(1, { outcome: :bound })
      #
      #   # good
      #   counter.increment({ outcome: :bound }, 1)
      #
      #   # bad - freezes the mistake into a passing spec
      #   expect(counter).to receive(:increment).with(labels: { outcome: :bound })
      #
      #   # good
      #   expect(counter).to receive(:increment).with({ outcome: :bound })
      #
      class PrometheusMetricLabels < Base
        extend AutoCorrector

        MSG_LABELS_KEYWORD = "Pass Prometheus labels positionally, not as a `labels:` keyword. " \
                             "`increment`/`observe`/`decrement` take no keyword arguments, so this " \
                             "becomes a single series labelled `labels=\"{...}\"` and by-label " \
                             "queries never match. Use `increment({ outcome: :bound })`.".freeze

        MSG_VALUE_FIRST = "`observe` takes the value first and the labels second: " \
                          "`observe(value, { outcome: :ok })`. A labels hash in the first position " \
                          "is recorded as the observed value.".freeze

        MSG_LABELS_FIRST = "`%<method>s` takes the labels first and the value second: " \
                           "`%<method>s({ outcome: :ok }, 1)`. This is the reverse of `observe`.".freeze

        MSG_STUBBED_LABELS = "Stubbing `increment` with a `labels:` keyword asserts a label shape " \
                             "prometheus_exporter never produces, so the spec stays green while " \
                             "the metric is broken. Match the positional hash instead: " \
                             "`.with({ outcome: :bound })`.".freeze

        LABELS_FIRST_METHODS = [:increment, :decrement].freeze
        VALUE_FIRST_METHODS = [:observe].freeze
        METRIC_METHODS = (LABELS_FIRST_METHODS + VALUE_FIRST_METHODS).freeze

        # `expect(counter).to receive(:increment).with(...)` and the
        # `have_received` spy equivalent.
        def_node_matcher :stubbed_metric_expectation?, <<~PATTERN
          (send
            (send nil? {:receive :have_received} (sym {:increment :decrement :observe}))
            :with ...)
        PATTERN

        def on_send(node)
          check_stubbed_labels_keyword(node)

          return unless node.receiver && METRIC_METHODS.include?(node.method_name)

          # A `labels:` key is the more specific diagnosis, so when it is
          # present it wins and the positional checks stay quiet.
          return if check_labels_keyword(node)

          check_argument_order(node)
        end

        private

        def check_labels_keyword(node)
          pair = labels_pair(trailing_hash(node))
          return false unless pair

          register_labels_keyword_offense(node, pair, MSG_LABELS_KEYWORD)
          true
        end

        def check_stubbed_labels_keyword(node)
          return unless stubbed_metric_expectation?(node)

          pair = labels_pair(trailing_hash(node))
          return unless pair

          register_labels_keyword_offense(node, pair, MSG_STUBBED_LABELS)
        end

        def check_argument_order(node)
          arguments = node.arguments
          return if arguments.empty?

          if VALUE_FIRST_METHODS.include?(node.method_name)
            add_offense(arguments.first, message: MSG_VALUE_FIRST) if arguments.first.hash_type?
          elsif value_before_labels?(arguments)
            add_offense(node, message: format(MSG_LABELS_FIRST, method: node.method_name))
          end
        end

        # Only the unambiguous flip: a bare number where the labels belong,
        # followed by the labels hash. Anything less literal than that could
        # be a non-metric `increment` (`Rails.cache`, atomics) and is left
        # alone.
        def value_before_labels?(arguments)
          arguments.size == 2 && arguments.first.numeric_type? && arguments.last.hash_type?
        end

        def trailing_hash(node)
          last_argument = node.arguments.last
          last_argument if last_argument&.hash_type?
        end

        def labels_pair(hash)
          return unless hash

          hash.pairs.find { |pair| pair.key.sym_type? && pair.key.value == :labels }
        end

        def register_labels_keyword_offense(node, pair, message)
          add_offense(pair, message:) do |corrector|
            # Unwrapping is only safe when `labels:` is the whole hash;
            # with siblings present there is no single value to hoist.
            hash = trailing_hash(node)
            corrector.replace(hash, pair.value.source) if hash.pairs.one?
          end
        end
      end
    end
  end
end
