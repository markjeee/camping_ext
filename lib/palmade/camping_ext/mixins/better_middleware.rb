module Palmade::CampingExt
  module Mixins
    module BetterMiddleware
      module ModuleMethods
        def call_with_better_middleware(e)
          ma = build_middleware_app!
          if ma.nil?
            call_without_better_middleware(e)
          else
            ma.call(e)
          end
        end

        def use_with_better_middleware(*a)
          a.unshift(:use)

          if defined?(@middlewares)
            @middlewares.push(a)
          else
            @middlewares = [ a ]
          end
        end

        protected

        def build_middleware_app!
          if defined?(@middleware_app)
            @middleware_app
          elsif defined?(@middlewares) && @middlewares.size > 0
            mws = @middlewares
            run = lambda { |e| call_without_better_middleware(e) }
            @middleware_app = Rack::Builder.new do |b|
              mws.each { |m| b.send(*m) }
              b.run(run)
            end
          else
            @middleware_app = nil
          end
        end
      end

      def self.included(base)
        base.extend(ModuleMethods)
        class << base
          alias :call_without_better_middleware :call
          alias :call :call_with_better_middleware

          alias :use_without_better_middleware :use
          alias :use :use_with_better_middleware
        end
      end
    end
  end
end
