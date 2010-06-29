module Palmade::CampingExt
  module Mixins
    module Reloader
      # this is stolen from Rails
      # see action_pack/action_controller/reloader.rb
      # yes, i have no shame!
      class BodyWrapper
        @@default_lock = Mutex.new

        def initialize(body, &block)
          @body = body
          @lock = @@default_lock
          @block = block
        end

        def close
          @body.close if @body.respond_to?(:close)
        ensure
          @block.call unless @block.nil?
          @lock.unlock
        end

        def method_missing(*args, &block)
          @body.send(*args, &block)
        end

        def respond_to?(symbol, include_private = false)
          symbol == :close || @body.respond_to?(symbol, include_private)
        end
      end

      class RackReloader
        def initialize(app, me, &block)
          @me = me
          @app = app
        end

        def call(e)
          me = @me
          reload_proc = lambda do
            #STDERR.puts "CLEANING UP"
            # reload if we have a reload singleton method
            reload! if me.respond_to?(:reload!)

            # do a reload if Rails is used
            ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)

            # let's remove already deleted constants from the route table
            controllers = me.const_get(:Controllers)
            controllers.r.delete_if do |k|
              if k.respond_to?(:parent)
                p = k.parent
                nm = k.name.gsub("#{p.name}::", '')
                p.const_defined?(nm) == false
              else
                false
              end
            end
          end

          status, headers, body = @app.call(e)
          body = BodyWrapper.new(body, &reload_proc)

          [ status, headers, body ]
        rescue Exception => e
          reload_proc.call
          raise e
        end
      end

      def self.included(base)
        base.use(RackReloader, base)
      end
    end
  end
end
