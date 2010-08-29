module Palmade::CampingExt
  module Mixins
    autoload :Glue, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/glue')
    autoload :Benchmarking, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/benchmarking')
    autoload :RestRoutes, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/rest_routes')
    autoload :Reloader, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/reloader')
    autoload :DynamicRoutes, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/dynamic_routes')
    autoload :BetterMiddleware, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/better_middleware')
    autoload :ExceptionHandling, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/exception_handling')
    autoload :CharsetEncoding, File.join(CAMPING_EXT_LIB_DIR, 'camping_ext/mixins/charset_encoding')
  end
end
