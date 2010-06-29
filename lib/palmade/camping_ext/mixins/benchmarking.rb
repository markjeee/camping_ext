module Palmade::CampingExt
  module Mixins
    module Benchmarking
      module Base
        def service_with_benchmarking(*a, &block)
          rt = ret = nil

          path_n_method = " [#{@request.request_method.to_s.upcase} #{@request.path rescue 'unknown'}]"
          tm = Time.now.strftime("%Y-%m-%d %H:%M:%S")

          # log processing request
          log_message = "\n\nProcessing #{self.class.name}\##{@method}"
          log_message << " (for #{@request.ip} at #{tm})"
          log_message << path_n_method
          logger.info(log_message)

          logger.debug do
            "  Parameters: #{@input.inspect}"
          end

          rt = [ Benchmark.measure { ret = service_without_benchmarking(*a, &block) }.real, 0.0001 ].max
          ret
       ensure
          unless rt.nil?
            # log completed time, response, and url
            log_message = "Completed in #{sprintf("%.5f", rt)} (#{(1 / rt).floor} reqs/sec)"
            log_message << " | #{@status}"
            log_message << path_n_method
            #log_message << " #{@request.env.inspect}"
            logger.info(log_message)

            # attach run-time response
            @headers["X-Runtime"] = sprintf("%.5f", rt)
          end
        end
      end

      def self.included(base)
        require 'benchmark'

        base_controller = base.const_get(:Base)
        base_controller.send(:include, Palmade::CampingExt::Mixins::Benchmarking::Base)
        base_controller.module_eval do
          alias :service_without_benchmarking :service
          alias :service :service_with_benchmarking
        end
      end
    end
  end
end
