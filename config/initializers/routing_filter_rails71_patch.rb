# routing-filter 0.7.0 is broken on Rails 7.1+ due to a change in how
# ActionDispatch::Journey::Router#find_routes yields results (lazy iterator
# vs eager enumerable). This patch restores the expected behaviour.
# See: https://github.com/svenfuchs/routing-filter/pull/87
# Remove this file if routing-filter ever releases a fixed version,
# or when routing-filter is replaced with native Rails i18n scope routing.

if Gem.loaded_specs['routing-filter'].version > Gem::Version.new('0.7.0')
  raise 'routing-filter has been updated — check if this patch is still needed and remove it if so.'
end

ActionDispatchJourneyRouterWithFiltering.remove_method(:find_routes)

module RoutingFilterRails71Fix
  def find_routes(env)
    path = env.is_a?(Hash) ? env['PATH_INFO'] : env.path_info
    filter_parameters = {}
    original_path = path.dup

    @routes.filters.run(:around_recognize, path, env) do
      filter_parameters
    end

    super(env) do |match, parameters, route|
      parameters = parameters.merge(filter_parameters)

      if env.is_a?(Hash)
        env['PATH_INFO'] = original_path
      else
        env.path_info = original_path
      end

      yield [match, parameters, route]
    end
  end
end

ActionDispatch::Journey::Router.prepend(RoutingFilterRails71Fix)
