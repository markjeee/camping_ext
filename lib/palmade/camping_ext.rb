CAMPING_EXT_LIB_DIR = File.dirname(__FILE__) unless defined?(CAMPING_EXT_LIB_DIR)
CAMPING_EXT_ROOT_DIR = File.join(CAMPING_EXT_LIB_DIR, '../..') unless defined?(CAMPING_EXT_ROOT_DIR)

module Palmade
  module CampingExt
    autoload :Mixins, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins')
    autoload :Inflector, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/inflector')
    autoload :Grounds, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/grounds')

    DEFAULT_OPTIONS = {
      :parse_rest_routes => true,
      :enforce_encoding => true
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

      # attach charset enforcer for rack.input data (only 1.9)
      if options[:enforce_encoding] && "1.9".respond_to?(:encoding)
        mod.send(:include, Palmade::CampingExt::Mixins::CharsetEncoding)
      end

      # allows use of PUT and DELETE methods with POST
      mod.use Rack::MethodOverride

      # add exception handling and logging
      mod.send(:include, Palmade::CampingExt::Mixins::ExceptionHandling)

      # attach exception handling as the top most
      unless mod.production?
        mod.use Rack::ShowExceptions
        mod.send(:include, Palmade::CampingExt::Mixins::Reloader)
      end

      # attach extension to rest routing, Camping::Controllers::REST
      if options[:parse_rest_routes]
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
