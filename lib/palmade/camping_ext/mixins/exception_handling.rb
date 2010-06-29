module Palmade::CampingExt
  module Mixins
    module ExceptionHandling
      # app level module methods
      module ModuleMethods
        # r500(:I, k, m, $!, :env => e).to_a
        def r500(c, *a)
          ex = a[2]

          # TODO: Add support for sending e-mail or submitting somewhere
          logger.error("#{ex.class.name}: #{ex.message}")
          logger.error("#{ex.backtrace.join("\n")}")

          raise ex
        end
      end

      # controller base methods
      module Base
        def service_with_exception_handling(*a)
          service_without_exception_handling(*a)
        rescue
          r500(self.class, @method, $!)
        end
      end

      def self.included(base)
        base.extend(ModuleMethods)

        base_controller = base.const_get(:Base)
        base_controller.send(:include, Base)
        base_controller.module_eval do
          alias :service_without_exception_handling :service
          alias :service :service_with_exception_handling
        end
      end
    end
  end
end
