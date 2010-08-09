module Palmade::CampingExt
  module Mixins
    module RestRoutes
      DEFAULT_OPTIONS = { }
      class RestRouteError < StandardError; end

# http://microformats.org/wiki/rest/urls
#
# The principal unit of operation is the "collection", which typically corresponds to a database table or (in Rails) an ActiveRecord class. For a collection named "people", the primary routes would be:

# Operate on the Collection
#   GET /people
# return a list of all records
#   GET /people/new
# return a form for creating a new record
#   POST /people
# submit fields for creating a new record

# Operate on a Record
#   GET /people/1
# return the first record
#   DELETE /people/1
# destroy the first record
#   POST /people/1?_method=DELETE
# alias for DELETE, to compensate for browser limitations
#   GET /people/1/edit
# return a form to edit the first record
#   PUT /people/1
# submit fields for updating the first record
#   POST /people/1?_method=PUT
# alias for PUT, to compensate for browser limitations

# Follow a Relationship
#   GET /people/1/phones
# return the collection of phone numbers associated with the first person
#   GET /people/1/phones/23
# return the phone number with id #23 associated with the first person
#   GET /people/1/phones/new
# return a form for creating a new phone number for the first person
#   POST /people/1/phones/
# submit fields for creating a new phone number for the first person

# Invoke Custom Actions
# It isn't always possible to map everything into CRUD. Thus, there is also a syntax for specifying custom actions:

# POST /people/1/promote
# run the "promote" action against the first record
# These should be used sparingly, as they are unlikely to be supported by most clients.

# File Formats
# Data types are extremely important in REST. While it is ideal to specify the appropriate MIME type as an HTTP header, developers are encouraged to follow Rails in allowing extension-based typing, e.g.:

# HTML
# GET /people/1
# return the first record in HTML format
# GET /people/1.html
# return the first record in HTML format
# XML
# GET /people/1.xml
# return the first record in XML format
# JSON
# GET /people/1.json
# return the first record in JSON format
# While the JSON mapping should be trivially obvious, the best practice for XML is to:

# use the column name as the element name
# include an appropriate "type" field
# See the Highrise reference for an example of how this works in practice.

      class RestRouteParser
        def initialize(app, camping, options = { })
          @app = app
          @camping = camping
        end

        def call(env)
          begin
            actions, rest_input, custom_meth = path_parser(Rack::Utils.unescape(env['PATH_INFO']), env["REQUEST_METHOD"].upcase)
            env["rack.rest_route.parsed"] = actions
            env["rack.rest_route.input"] = rest_input
            env["rack.rest_route.custom_method"] = custom_meth

            # STDERR.puts "Parsed REST URL: #{env['PATH_INFO']} => #{actions.inspect}"
          rescue RestRouteError => e
            @camping.logger.warn("RestRouteError: #{e.message}")

            env["rack.rest_route.parsed"] = nil
            env["rack.rest_route.input"] = nil
            env["rack.rest_route.custom_method"] = nil
          end

          @app.call(env)
        end

        # TODO: !!!!
        # This can refactored to run on C as a ruby-native extension
        # TODO: !!!!
        def path_parser(path, method)
          comps = path.gsub(/^#{@camping.path_prefix}/, '').split('/')

          # this is a hack on REST urls, since i can't seem to find a way to
          # determine a head if a component is a resource id or a custom action
          # i'm using '!' here, could be different it this violates anything
          # - markj
          custom_meth = nil
          if !comps.last.nil? && comps.last.include?('!')
            comps[-1], custom_meth = comps.last.split('!', 2)
          end

          # delete any component if empty
          comps.delete_if { |c| c.empty? }

          #STDERR.puts "Parsing with: #{comps.inspect}; #{custom_meth}"

          actions = [ ]
          rest_input = { }

          state = :collection
          id = nil
          collection = comps.shift

          comps.each do |c|
            raise RestRouteError, "Invalid rest path: #{id}" if [ nil, '' ].include?(c)

            case state
            when :end
              raise RestRouteError, "Invalid rest path, state :end, but got #{c}"
            when :collection
              case c
              when 'new'
                actions += [ :new, nil, collection ]
                state = :end
              when 'edit'
                raise RestRouteError, "Invalid rest path, state :collection, but got :edit"
              else
                id = c
                state = :show
              end
            when :show
              case c
              when 'new'
                raise RestRouteError, "Invalid rest path, state :show, but got :new"
              when 'edit'
                actions += [ :edit, id, collection ]
                state = :end
              else
                actions += [ :show, id, collection ]
                rest_input[collection] = id

                collection = c
                state = :collection
              end
            end
          end unless comps.empty?

          case state
          when :collection
            case method
            when 'GET'
              actions += [ (custom_meth || :index), nil, collection ]
            when 'POST'
              actions += [ (custom_meth || :create), nil, collection ]
            else
              raise RestRouteError, "Invalid method for route #{path}, got #{method}"
            end
          when :show
            case method
            when 'GET'
              actions += [ (custom_meth || :show), id, collection ]
              rest_input[collection] = id
            when 'PUT'
              actions += [ (custom_meth || :update), id, collection ]
              rest_input[collection] = id
            when 'DELETE'
              actions += [ (custom_meth || :delete), id, collection ]
              rest_input[collection] = id
            when 'POST'
              if custom_meth.nil?
                raise RestRouteError, "Invalid method for route #{path}, got #{method}"
              else
                actions += [ custom_meth, id, collection ]
              end
            else
              raise RestRouteError, "Invalid method for route #{path}, got #{method}"
            end
          end

          [ actions, rest_input, custom_meth ]
        end
      end

      module RestMethods
        attr_reader :rest_route
        attr_reader :rest_input

        def get(*a)
          # /r - index
          # /r/new - new
          # /r/1 - show
          # /r/1/edit - edit

          # /r/1/coll - index
          # /r/1/coll/new - new
          # /r/1/coll/2 - show collection
          perform_action(*a)
        end

        def post(*a)
          # /r - create
          # /r/1/coll - create

          # NOTE: rack already supports method override
          # /r/1?_method=DELETE - delete
          # /r/1?_method=PUT - update
          perform_action(*a)
        end

        def put(*a)
          # /r/1 - update
          # /r/1/coll/2 - update coll
          perform_action(*a)
        end

        def delete(*a)
          # /r/1 - delete
          # /r/1/coll/2 - delete coll
          perform_action(*a)
        end

        protected

        def parse_rest_routes
          @rest_input = @env['rack.rest_route.input']
          @rest_route = @env['rack.rest_route.parsed']
        end

        def perform_action(*a)
          rr = parse_rest_routes
          logger.debug { "  Rest route: #{@rest_route.inspect}" }
          logger.debug { "  Rest parameter: #{@rest_input.inspect}" }

          unless rr.nil?
            meth = rr[-3]
            id = rr[-2]

            if self.respond_to?(meth)
              if id.nil?
                logger.info("  Performing rest action: #{meth} on #{self.class.name}")
                self.send(meth)
              else
                logger.info("  Performing rest action: #{meth} for #{id} on #{self.class.name}")
                self.send(meth, id)
              end
            else
              r(405, "Method not defined: #{meth}")
            end
          else
            r(404, "File not found: #{@env['PATH_INFO']}")
          end
        end
      end

      module Controllers
        def REST(*u)
          if u.last.is_a?(Hash)
            options = DEFAULT_OPTIONS.merge(u.pop)
          else
            options = DEFAULT_OPTIONS.merge({ })
          end

          r = self.r
          camping = self.camping
          rest_methods = RestMethods
          c = Class.new do
            meta_def(:rest_route?) { true }
            meta_def(:inherited) do |x|
              r << x
              x.send(:include, camping.const_get(:Base))
              x.send(:include, camping.const_get(:Helpers))
              x.send(:include, rest_methods)
            end

            meta_def(:urls) do
              if defined?(@urls)
                @urls
              else
                me = camping.const_get(:Controllers)
                nm = Palmade::CampingExt::Inflector.underscore(self.name.gsub("#{me}::", ""))
                pp = camping.path_prefix

                @urls = [ "#{pp}#{nm}",
                          "#{pp}#{nm}\!.+",
                          "#{pp}#{nm}/new",
                          "#{pp}#{nm}\/[^\/]+\/edit",
                          "#{pp}#{nm}\/[^\/]+",
                          "#{pp}.+\/#{nm}",
                          "#{pp}.+\/#{nm}\!.+",
                          "#{pp}.+\/#{nm}\/new",
                          "#{pp}.+\/#{nm}\/[^\/]+\/edit",
                          "#{pp}.+\/#{nm}\/[^\/]+"
                        ]
              end
            end
          end
        end
      end

      def self.included(base)
        controllers = base.const_get(:Controllers)
        controllers.extend(Controllers)

        base.use RestRouteParser, base
      end
    end
  end
end
