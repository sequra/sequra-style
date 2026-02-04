module RuboCop
  module Cop
    module Sequra
      # Detects Sidekiq jobs that haven't adopted the ApplicationOperation pattern.
      #
      # A job is considered migrated when it meets ALL conditions:
      # 1. Has exactly ONE `*Operation.call` invocation (delegates to single operation)
      # 2. Class length ≤ 10 "smart lines" (using CountAsOne semantics)
      #
      # A job is considered unmigrated (offense) when:
      # - Zero `Operation.call` → business logic lives in the job itself
      # - Multiple `Operation.call` → job orchestrates multiple operations
      # - Exceeds class length → job has too much logic beyond delegation
      #
      # @example
      #   # bad - no operation delegation
      #   class MyJob < ApplicationJob
      #     def perform(id)
      #       user = User.find(id)
      #       user.update!(status: :active)
      #       UserMailer.welcome(user).deliver_later
      #     end
      #   end
      #
      #   # bad - multiple operations
      #   class MyJob < ApplicationJob
      #     def perform(id, type)
      #       if type == :a
      #         OperationA.call(id: id)
      #       else
      #         OperationB.call(id: id)
      #       end
      #     end
      #   end
      #
      #   # good - single operation delegation
      #   class MyJob < ApplicationJob
      #     def perform(id)
      #       MyOperation.call(id:)
      #     end
      #   end
      #
      class AsyncJobPattern < Base
        MSG = "Sidekiq job should delegate to exactly one Operation".freeze
        MSG_CLASS_LENGTH = "Job has too much logic to be a simple Operation delegate. " \
                           "Consider moving logic into the Operation".freeze

        MAX_CLASS_LENGTH = 10
        COUNT_AS_ONE = ["array", "hash", "heredoc", "method_call"].freeze

        def_node_matcher :application_job_subclass?, <<~PATTERN
          (class _ (const nil? :ApplicationJob) ...)
        PATTERN

        def_node_matcher :includes_sidekiq_worker?, <<~PATTERN
          (send nil? :include (const (const nil? :Sidekiq) {:Worker :Job}))
        PATTERN

        def_node_matcher :operation_call?, <<~PATTERN
          (send (const _ /Operation$/) :call ...)
        PATTERN

        def on_class(node)
          return unless sidekiq_job?(node)

          check_operation_delegation(node)
          check_class_length(node)
        end

        private

        def sidekiq_job?(node)
          return true if application_job_subclass?(node)

          node.body&.each_descendant(:send)&.any? { |send_node| includes_sidekiq_worker?(send_node) }
        end

        def check_operation_delegation(node)
          operation_calls = find_operation_calls(node)

          return if operation_calls.size == 1

          add_offense(node.loc.name, message: MSG)
        end

        def find_operation_calls(node)
          return [] unless node.body

          node.body.each_descendant(:send).select { |send_node| operation_call?(send_node) }
        end

        def check_class_length(node)
          return unless node.body

          length = class_length(node)
          return if length <= MAX_CLASS_LENGTH

          add_offense(node.loc.keyword, message: MSG_CLASS_LENGTH)
        end

        def class_length(node)
          return 0 unless node.body

          body_lines = line_range(node.body)
          count_lines(body_lines, node)
        end

        def line_range(node)
          node.loc.first_line..node.loc.last_line
        end

        def count_lines(range, node)
          source_lines = processed_source.lines[(range.begin - 1)..(range.end - 1)]
          return 0 if source_lines.nil?

          effective_lines = source_lines.reject { |line| irrelevant_line?(line) }

          # Subtract lines that should count as one
          count_as_one_adjustment = count_as_one_lines(node)

          [effective_lines.size - count_as_one_adjustment, 0].max
        end

        def irrelevant_line?(line)
          line.strip.empty? || line.strip.start_with?("#")
        end

        def count_as_one_lines(node)
          adjustment = 0
          return adjustment unless node.body

          node.body.each_descendant do |descendant|
            next unless count_as_one_node?(descendant)

            lines = descendant.loc.last_line - descendant.loc.first_line
            adjustment += lines if lines.positive?
          end

          adjustment
        end

        def count_as_one_node?(node)
          COUNT_AS_ONE.any? { |type| node_matches_type?(node, type) }
        end

        def node_matches_type?(node, type)
          case type
          when "array" then node.array_type?
          when "hash" then node.hash_type?
          when "heredoc" then node.str_type? && node.heredoc?
          when "method_call" then multiline_method_call?(node)
          end
        end

        def multiline_method_call?(node)
          node.send_type? &&
            node.loc.respond_to?(:selector) &&
            node.loc.selector &&
            node.loc.first_line != node.loc.last_line
        end
      end
    end
  end
end
