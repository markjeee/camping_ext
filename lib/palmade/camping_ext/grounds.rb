module Palmade::CampingExt
  class Grounds
    DEFAULT_OPTIONS = {
      :path_prefix => nil,
      :environment => 'development'
    }

    def initialize(logger, options = { })
      @logger = logger
      @options = DEFAULT_OPTIONS.merge(options)

      @app = nil
      @map = { }
      @default_map = nil
      @map_keys = nil
    end

    def map(url, mod)
      url = url.to_s
      raise "URL prefix can't be nil or empty" if url.empty?

      @map[url] = mod
    end

    def default(mod)
      @default_map = mod
    end

    def call(env)
      # frozen maps
      @map_keys = @map.keys.collect { |m| m.freeze }.freeze if @map_keys.nil?

      pi = Rack::Utils.unescape(env['PATH_INFO'])
      mod = @default_map
      @map_keys.each do |m|
        if pi =~ /\A#{@options[:path_prefix]}#{m}(.*)\Z/
          env['ORIG_PATH_INFO'] = pi
          env['PATH_INFO'] = $~[1].empty? ? '/' : $~[1]
          env['CAMPING_GROUNDS_MAP'] = m

          @logger.debug { "Camping ground mapped #{m} => #{pi}" }
          mod = @map[m]

          break
        end
      end

      unless mod.nil?
        mod.call(env)
      else
        r404
      end
    end

    protected

    def production?
      @options[:environment] == 'production'
    end

    def r404
      if production?
        body = "Not found"
      else
        body = "<h1>Not found (Camping Grounds)</h1>"
      end

      [ 404,
        { "Content-Type" => "text/plain",
          "Content-Length" => body.size.to_s },
        body ]
    end
  end
end
