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
          unless k.include?(base)
            k.send :include, base, helpers, models
          end

          # let's include it in the list of routes
          unless r.include?(k)
            r.unshift(k)
          end

          k
        end

        def D_with_dynamic_routes(p, m, env)
          k, new_m, *a = D_without_dynamic_routes(p, m, env)
          if new_m == 'r404'
            unless (actions = env['rack.rest_route.parsed']).nil?
              unless actions.last.nil?
                klass_name = Palmade::CampingExt::Inflector.camelize(actions.last)
              else
                klass_name = "Index"
              end
            else
              if p =~ /^#{camping.path_prefix}\/?([^\/]+)/
                klass_name = Palmade::CampingExt::Inflector.camelize($~[1])
              else
                klass_name = "Index"
              end
            end

            controllers = camping.const_get(:Controllers)
            base = camping.const_get(:Base)

            try_loading = lambda do |kname|
              controller_name = "#{controllers.name}::#{kname}"
              camping.logger.debug { "Trying Controller #{controller_name}" }

              klass = nil
              if camping.production?
                klass = eval(controller_name, TOPLEVEL_BINDING) rescue nil
              else
                klass = eval(controller_name, TOPLEVEL_BINDING)
              end

              unless klass.nil?
                controllers.add_route(klass)
                k, new_m, *a = D_without_dynamic_routes(p, m, env)
              end
            end

            # expected klass_name, -- by default, doesn't support
            # class names with numbers on them.
            unless klass_name =~ /[^A-Za-z\_]/
              klass = nil

              # this is an added measure, since i noticed sometimes,
              # if there's another constant, a global for example,
              # that has the same name, const_defined? will return
              # true (i noticed this on ruby 1.9.2), even if it is not
              # a camping controller. So the added check on
              # repond_to?(:urls) and Base model included, is to make
              # sure if the constant indeed is a camping
              # controller. or probably just something
              # else. Othwerise, we'll try to load it again, just in
              # case. OORRRR, this could be a entirely wrong idea.
              if controllers.const_defined?(klass_name)
                klass = controllers.const_get(klass_name)
                unless klass.nil?
                  klass = nil unless klass.respond_to?(:urls) && klass.include?(base)
                end
              end

              try_loading.call(klass_name) if klass.nil?
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
