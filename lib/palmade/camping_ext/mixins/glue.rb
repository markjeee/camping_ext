module Palmade::CampingExt
  module Mixins
    module Glue
      module Base
        protected

        def logger
          self.class.logger
        end

        def camping
          self.class.camping
        end
      end

      def self.included(base)
        # extend the top-most camping module
        class << base
          attr_accessor :env
          attr_accessor :root
          attr_accessor :logger
          attr_accessor :path_prefix

          def production?
            env.to_s == 'production'
          end
        end

        # the default path prefix is the root path
        base.path_prefix = '/'

        attach_camping = lambda do |mod_sym|
          mod = base.const_get(mod_sym)
          class << mod
            attr_reader :camping
          end
          mod.instance_variable_set(:@camping, base)
          mod
        end

        # let's get the Camping::Base included in this module
        attach_camping.call(:Controllers)
        attach_camping.call(:Views)
        base_controller = attach_camping.call(:Base)

        # attach base controller instance methods
        base_controller.send(:include, Palmade::CampingExt::Mixins::Glue::Base)

        # extend the base controller instance methods
        class << base_controller
          def included(base)
            class << base
              attr_accessor :camping

              def logger
                if defined?(@logger)
                  @logger
                else
                  # let's get it from the top-most module
                  @logger = camping.logger
                end
              end
            end
            base.camping = camping
          end
        end
      end
    end
  end
end
