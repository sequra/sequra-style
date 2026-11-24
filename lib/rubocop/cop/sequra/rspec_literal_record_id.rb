# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequra
      class RSpecLiteralRecordId < Base
        MSG = "Do not give a created record a literal id: sequences are not rolled back with the transaction, " \
              "so another spec on the same worker can take it first. Let the record get its own id and refer " \
              "to it (spec-determinism.md)."

        def_node_matcher :literal_id_pair, <<~PATTERN
          (send {nil? (const {nil? cbase} :FactoryBot)} {:create :create_list} ... (hash <$(pair (sym :id) int) ...>))
        PATTERN

        def on_send(node)
          literal_id_pair(node) { |pair| add_offense(pair) }
        end
      end
    end
  end
end
