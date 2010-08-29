module Palmade::CampingExt
  module Mixins
    module CharsetEncoding
      DEFAULT_OPTIONS = { :charset_encoding => 'BINARY' }

      class CharsetEncodingEnforcer
        def initialize(app, camping, options = { })
          @options = DEFAULT_OPTIONS.merge(options)

          @app = app
          @camping = camping
        end

        def call(env)
          @app.call(enforce_encoding(env))
        end

        def enforce_encoding(env)
          r = Rack::Request.new(env)

          http_enc = r.content_charset
          enc = Encoding.find(http_enc || @options[:charset_encoding])

          unless enc.nil?
            env['HTTP_CONTENT_CHARSET'] = http_enc
            env['CONTENT_CHARSET'] = enc

            form_hash = r.POST

            # note, only values are being enforced for now. it looks
            # like Rack::Request#POST freezes the keys.
            form_hash.values.each { |v| v.force_encoding(enc) if v.respond_to?(:force_encoding) }
          end

          env
        end
      end

      def self.included(base)
        base.use CharsetEncodingEnforcer, base
      end
    end
  end
end
