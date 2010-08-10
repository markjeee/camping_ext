module Palmade::CampingExt
  module Mixins
    module BetterMiddleware
      module MiddlewareHelper
        def middleware_use(*a, &block)
          a.unshift(:use)
          a.push(block)

          if defined?(@middlewares)
            @middlewares.push(a)
          else
            @middlewares = [ a ]
          end
        end

        def middleware_build!(&run)
          if defined?(@middleware_app)
            @middleware_app
          elsif defined?(@middlewares) && @middlewares.size > 0
            mws = @middlewares
            @middleware_app = Rack::Builder.new do |b|
              mws.each do |m|
                block = m.pop
                if block.nil?
                  b.send(*m)
                else
                  b.send(*m, &block)
                end
              end
              b.run(run)
            end
          else
            @middleware_app = run
          end
        end
      end

      module ModuleMethods
        def call_with_better_middleware(e)
          ma = middleware_build! { |le| call_without_better_middleware(le) }
          ma.call(e)
        end

        def use_with_better_middleware(*a, &block)
          middleware_use(*a, &block)
        end
      end

      module Base
        module ClassMethods
          def use(*a, &block)
            middleware_use(*a, &block)
          end

          def call(env)
            me = env['CAMPING_CONTROLLER']
            svc_args = env['CAMPING_CONTROLLER_ARGS']
            svc_block = env['CAMPING_CONTROLLER_BLOCK']

            unless me.nil?
              if me.body.nil?
                me.service_without_better_middleware(*svc_args)
              else
                me
              end
            else
              raise "Impossible to get here, can't be."
            end
          end
        end

        def service_with_better_middleware(*a, &block)
          @env['CAMPING_CONTROLLER'] = self
          @env['CAMPING_CONTROLLER_SERVICE_ARGS'] = a
          @env['CAMPING_CONTROLLER_SERVICE_BLOCK'] = block

          ma = self.class.middleware_build!(&self.class.method(:call))
          ma.call(@env)
        end
      end

      def self.included(base)
        base.extend(MiddlewareHelper)
        base.extend(ModuleMethods)

        class << base
          alias :call_without_better_middleware :call
          alias :call :call_with_better_middleware

          alias :use_without_better_middleware :use
          alias :use :use_with_better_middleware
        end

        base_controller = base.const_get(:Base)
        base_controller.included_chain do |controller|
          raise "Double include! #{Base.name} #{controller.name}" if controller.include?(Base)

          controller.extend(MiddlewareHelper)
          controller.extend(Base::ClassMethods)

          controller.send(:include, Base)
          controller.class_eval do
            alias :service_without_better_middleware :service
            alias :service :service_with_better_middleware
          end
        end
      end
    end
  end
end
