module RuboCop
  module Cop
    module Sequra
      # Detects RSpec stubs and spy assertions on Sidekiq enqueue methods
      # (`perform_async`, `perform_at`, `perform_in`) and on the mailer
      # enqueue wrapper (`SomeMailer.later`).
      #
      # Stubbing these methods bypasses `Sidekiq.strict_args!` validation,
      # which lets symbol-keyed hashes (and other non-JSON-native types)
      # slip through unchecked. The same code would raise `ArgumentError`
      # in production at enqueue time, and the bug only surfaces when the
      # job actually runs — by which point retries, timing windows, and
      # rescue-swallowers can mask the failure. This pattern caused a
      # silent push-notification drop in COR-1923.
      #
      # `SomeMailer.later` (seQura's `ApplicationMailer.later`) is the
      # standard mailer enqueue path and funnels through
      # `ApplicationMailerJob.perform_async`, so stubbing it bypasses
      # `strict_args!` exactly like stubbing `perform_async` directly.
      # `.later` is only flagged when the stubbed subject is a `*Mailer`
      # constant, so unrelated `.later` methods are left alone.
      #
      # Use `have_enqueued_sidekiq_job` (or `change(SomeJob.jobs, :size)`)
      # instead. Both go through Sidekiq's client middleware chain, so
      # `strict_args!` validates the arguments as it would in production.
      #
      # `.and_call_original` is exempt: the stub spies on the call but
      # then runs the real method, which still exercises the
      # serialization contract.
      #
      # @example
      #   # bad - stub bypasses strict_args! validation
      #   allow(SomeJob).to receive(:perform_async)
      #
      #   # bad - even with arg matchers, the real enqueue is suppressed
      #   expect(SomeJob).to receive(:perform_at).with(time, data)
      #
      #   # bad - negative assertion still bypasses the contract
      #   expect(SomeJob).not_to receive(:perform_async)
      #
      #   # bad - spy verification on a stubbed enqueue
      #   expect(SomeJob).to have_received(:perform_async).with(id)
      #
      #   # bad - mailer enqueue wrapper bypasses strict_args! too
      #   allow(WelcomeMailer).to receive(:later)
      #
      #   # good - exercises strict_args! through Sidekiq's middleware
      #   expect(SomeJob).to have_enqueued_sidekiq_job(id, name: "value")
      #
      #   # good - state-based assertion, also exercises the middleware
      #   expect { subject }.to change(SomeJob.jobs, :size).by(1)
      #
      #   # good - escape hatch: spy AND run the real method
      #   expect(SomeJob).to receive(:perform_async).and_call_original
      #
      class NoSidekiqPerformStubs < Base
        MSG = "Avoid stubbing job/mailer enqueue methods (`perform_async`/`perform_at`/`perform_in`, " \
              "or `Mailer.later`). Stubs bypass `Sidekiq.strict_args!` validation and can hide " \
              "symbol-keyed hash bugs (see COR-1923). Use `have_enqueued_sidekiq_job` or " \
              "`change(Job.jobs, :size)` instead. Use `.and_call_original` only as an escape hatch.".freeze

        SUBJECT_WRAPPERS = [:allow, :expect, :allow_any_instance_of, :expect_any_instance_of].freeze

        def_node_matcher :perform_method_stub?, <<~PATTERN
          (send nil? {:receive :have_received} (sym {:perform_async :perform_at :perform_in}))
        PATTERN

        def_node_matcher :later_method_stub?, <<~PATTERN
          (send nil? {:receive :have_received} (sym :later))
        PATTERN

        def on_send(node)
          return unless perform_method_stub?(node) || mailer_later_stub?(node)
          return if chained_with_call_original?(node)

          add_offense(node)
        end

        private

        def mailer_later_stub?(node)
          return false unless later_method_stub?(node)

          subject = stubbed_subject(node)
          subject&.const_type? && subject.const_name.to_s.end_with?("Mailer")
        end

        def stubbed_subject(node)
          current = node
          current = current.parent while current.parent&.send_type? && current.parent.receiver == current

          matcher = current.parent
          return unless matcher&.send_type?

          wrapper = matcher.receiver
          return unless wrapper&.send_type? && SUBJECT_WRAPPERS.include?(wrapper.method_name)

          wrapper.first_argument
        end

        def chained_with_call_original?(node)
          current = node
          loop do
            parent = current.parent
            return false unless parent&.send_type? && parent.receiver == current
            return true if parent.method_name == :and_call_original

            current = parent
          end
        end
      end
    end
  end
end
