CAMPING_EXT_LIB_DIR = File.dirname(__FILE__) unless defined?(CAMPING_EXT_LIB_DIR)
CAMPING_EXT_ROOT_DIR = File.join(CAMPING_EXT_LIB_DIR, '../..') unless defined?(CAMPING_EXT_ROOT_DIR)

module Palmade
  module CampingExt
    autoload :Mixins, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins')
    autoload :Inflector, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/inflector')

    DEFAULT_OPTIONS = {
      :parse_rest_routes => true
    }

    def self.init(mod, env, root, logger, options = { })
      options = DEFAULT_OPTIONS.merge(options)

      case mod
      when String, Symbol
        mod = Object.const_get(mod.to_sym)
      end

      warn "** Initializing camping_ext for #{mod.name}"

      # attach the basic extensions
      mod.send(:include, Palmade::CampingExt::Mixins::Glue)
      mod.env, mod.root, mod.logger = env, root, logger

      # better middleware
      mod.send(:include, Palmade::CampingExt::Mixins::BetterMiddleware)

      # attach extension to benchmarking Camping::Controllers::service
      mod.send(:include, Palmade::CampingExt::Mixins::Benchmarking)

      # attach extension to routing Camping::Controllers::D
      mod.send(:include, Palmade::CampingExt::Mixins::DynamicRoutes)

      # allows use of PUT and DELETE methods with POST
      mod.use Rack::MethodOverride

      # add exception handling and logging
      mod.send(:include, Palmade::CampingExt::Mixins::ExceptionHandling)

      # attach exception handling as the top most
      unless mod.production?
        mod.use Rack::ShowExceptions
        mod.send(:include, Palmade::CampingExt::Mixins::Reloader)
      end

      if options[:parse_rest_routes]
        # attach extension to rest routing, Camping::Controllers::REST
        mod.send(:include, Palmade::CampingExt::Mixins::RestRoutes)
      end

      mod
    end

    def self.use_couch_potato(mod, options = { })
      case mod
      when String, Symbol
        mod = Object.const_get(mod.to_sym)
      end
      mod.use Palmade::CouchPotato::Session, options
    end
  end
end
