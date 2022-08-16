# frozen_string_literal: true

module Blacklight
  module Rendering
    class LinkToFacet < AbstractStep
      def render
        return next_step(values) unless config.link_to_facet && html?

        next_step(render_link)
      end

      private

      # This allows the link to wrap an itemprop
      def render_link
        values.map { |v| link(link_field, v) }
      end

      def link_field
        return config.key if config.link_to_facet == true

        config.link_to_facet
      end

      def link(field, v)
        context.link_to v, search_path(field, v)
      end

      def search_path(field, v)
        context.search_action_path(facet_params(field, v))
      end

      def facet_params(field, item)
        context.search_state.reset.filter(field).add(item).params
      end
    end
  end
end
