module Palmade::CampingExt
  module Mixins
    module DynamicRoutes
      module Controllers
        def add_route(k)
          me = camping.const_get(:Controllers)
          nm = Palmade::CampingExt::Inflector.underscore(k.name.gsub("#{me.name}::", ""))

          unless k.respond_to?(:urls)
            k.meta_def(:urls) { [ "#{camping.path_prefix}#{nm}" ] }
          end

          base = camping.const_get(:Base)
          helpers = camping.const_get(:Helpers)
          models = camping.const_get(:Models)

          # let's include the basic modules
          k.send :include, base, helpers, models

          # let's include it in the list of routes
          r.unshift(k) unless r.include?(k)

          k
        end

        def D_with_dynamic_routes(p, m, env)
          k, new_m, *a = D_without_dynamic_routes(p, m, env)
          if new_m == 'r404'
            unless env['rack.rest_route.parsed'].nil?
              actions = env['rack.rest_route.parsed']
              unless actions.last.nil?
                klass_name = Palmade::CampingExt::Inflector.camelize(actions.last)
              else
                klass_name = "Index"
              end
            else
              if p =~ /^\/?([^\/]+)/
                klass_name = Palmade::CampingExt::Inflector.camelize($~[1])
              else
                klass_name = "Index"
              end
            end

            controllers = camping.const_get(:Controllers)

            try_loading = lambda do |kname|
              controller_name = "#{controllers.name}::#{kname}"
              camping.logger.debug { "Trying Controller: #{controller_name}" }

              # if we were able to load a class, let's try loading again
              klass = eval(controller_name, TOPLEVEL_BINDING)
              unless klass.nil?
                controllers.add_route(klass)
                k, new_m, *a = D_without_dynamic_routes(p, m, env)
              end
            end

            # expected klass_name
            unless klass_name =~ /[^A-Za-z0-9\:\_\-]/
              unless controllers.const_defined?(klass_name)
                try_loading.call(klass_name)
              end
            end
          end

          [ k, new_m, *a ]
        end
      end

      def self.included(base)
        controllers = base.const_get(:Controllers)
        controllers.extend(Controllers)

        class << controllers
          alias :D_without_dynamic_routes :D
          alias :D :D_with_dynamic_routes
        end

        base_controller = base.const_get(:Base)
      end
    end
  end
end
