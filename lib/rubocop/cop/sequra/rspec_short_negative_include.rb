# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequra
      class RSpecShortNegativeInclude < Base
        MSG = "A short string of letters and digits, or an id, can appear by chance in random ids and tokens. " \
              "Assert the exact field or the whole value instead of its absence (spec-determinism.md)."

        MAX_LENGTH = 5

        def_node_matcher :negative_include_arguments, <<~PATTERN
          (send _ {:not_to :to_not} (send nil? :include $...))
        PATTERN

        def_node_matcher :id_to_s?, <<~PATTERN
          (send (send _ :id) :to_s)
        PATTERN

        def on_send(node)
          negative_include_arguments(node) do |arguments|
            arguments.each do |argument|
              add_offense(argument) if short_alphanumeric?(argument) || id_to_s?(argument)
            end
          end
        end

        private

        def short_alphanumeric?(node)
          node.str_type? && node.value.length <= MAX_LENGTH && node.value.match?(/\A[[:alnum:]]+\z/)
        end
      end
    end
  end
end
