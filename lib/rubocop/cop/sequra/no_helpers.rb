# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequra
      # Flags any module or class defined under an `app/helpers/` directory.
      #
      # Rails helpers are globally mixed into every view, so they have no owner, no
      # boundary and nothing to unit test. Display logic belongs to presenters (view
      # context), formatters (pure data transformation) and calculators (derived values).
      #
      # The check is path-based, not name-based: a class named `RoutingHelper` outside
      # `app/helpers/` is fine, and anything inside it is not. Any nesting depth is
      # covered, so pack and nested-pack helper directories are caught too.
      #
      # @example
      #   # bad - app/helpers/foo_helper.rb, packs/my_pack/app/helpers/foo_helper.rb
      #   module FooHelper
      #     def label(order) = order.reference
      #   end
      #
      #   # good - app/presenters/foo_presenter.rb
      #   class FooPresenter
      #     def label = order.reference
      #   end
      class NoHelpers < Base
        MSG = "Do not create helpers. Use presenters, formatters, or calculators instead."

        HELPER_PATH = %r{(^|/)app/helpers/}

        def on_module(node)
          add_offense(declaration_range(node)) if helper_file?
        end

        def on_class(node)
          add_offense(declaration_range(node)) if helper_file?
        end

        private

        # Keeps the highlight on the declaration instead of the whole body, which editors
        # would otherwise underline end to end.
        def declaration_range(node)
          node.loc.keyword.join(node.loc.name)
        end

        def helper_file?
          processed_source.file_path.match?(HELPER_PATH)
        end
      end
    end
  end
end
