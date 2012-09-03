module Rails3JQueryAutocomplete
  module Autocomplete
    def self.included(target)
      target.extend Rails3JQueryAutocomplete::Autocomplete::ClassMethods

      if defined?(Mongoid::Document)
        target.send :include, Rails3JQueryAutocomplete::Orm::Mongoid
      elsif defined?(MongoMapper::Document)
        target.send :include, Rails3JQueryAutocomplete::Orm::MongoMapper
      else
        target.send :include, Rails3JQueryAutocomplete::Orm::ActiveRecord
      end
    end

    #
    # Usage:
    #
    # class ProductsController < Admin::BaseController
    #   autocomplete :brand, :name
    # end
    #
    # This will magically generate an action autocomplete_brand_name, so,
    # don't forget to add it on your routes file
    #
    #   resources :products do
    #      get :autocomplete_brand_name, :on => :collection
    #   end
    #
    # Now, on your view, all you have to do is have a text field like:
    #
    #   f.text_field :brand_name, :autocomplete => autocomplete_brand_name_products_path
    #
    #
    # Yajl is used by default to encode results, if you want to use a different encoder
    # you can specify your custom encoder via block
    #
    # class ProductsController < Admin::BaseController
    #   autocomplete :brand, :name do |items|
    #     CustomJSONEncoder.encode(items)
    #   end
    # end
    #
    module ClassMethods
                       #course, [:prof, :name, :department, :school_name, :number, :school_symbol], options={:full => true, :extra_data => [:department, :name, :school_name, :number, :prof, :id, :school_symbol], :display_value => :autocomplete_display, :add_fields => [:school_symbol]}
      def autocomplete(object, method, options = {})
        define_method("autocomplete_#{object}_#{method.first}") do

          method = options[:column_name] if options.has_key?(:column_name)

          term = params[:term]
          add_fields = []         
                    
          if object == :course
            add_fields << "PO" if params[:po] == "true"
            add_fields << "CM" if params[:cm] == "true"
            add_fields << "HM" if params[:hm] == "true"
            add_fields << "SC" if params[:sc] == "true" 
            add_fields << "PZ" if params[:pz] == "true"
            add_fields << "JS" if params[:js] == "true"          
            puts add_fields
          else          
            puts "-- INSIDE AUTOCOMPLETE --"
            puts options[:add_fields]
            add_fields = {}
            if options[:add_fields]
              puts "Query Fields"
              if options[:add_fields].is_a?(Symbol)
                add_fields[options[:add_fields]] = params[options[:add_fields]] unless params[options[:add_fields]].blank?
                puts "Field: #{options[:add_fields]} Value: #{add_fields[options[:add_fields]]}"
              else
                options[:add_fields].each do |field|
                  add_fields[field] = params[field]
                  puts "Field: #{field} Value: #{add_fields[field]}"
                end
              end
            end
          end

          if term && !term.blank?
            #allow specifying fully qualified class name for model object
            class_name = options[:class_name] || object
            items = get_autocomplete_items(:model => get_object(class_name), \
              :options => options, :term => term, :method => method, :add_fields => add_fields)
          else
            items = {}
          end

          render :json => json_for_autocomplete(items, options[:display_value] ||= method.first, options[:extra_data])
        end
      end
    end

    # Returns a limit that will be used on the query
    def get_autocomplete_limit(options)
      options[:limit] ||= 10
    end

    # Returns parameter model_sym as a constant
    #
    #   get_object(:actor)
    #   # returns a Actor constant supposing it is already defined
    #
    def get_object(model_sym)
      object = model_sym.to_s.camelize.constantize
    end

    #
    # Returns a hash with three keys actually used by the Autocomplete jQuery-ui
    # Can be overriden to show whatever you like
    # Hash also includes a key/value pair for each method in extra_data
    #
    def json_for_autocomplete(items, method, extra_data=[])
      items.collect do |item|
        hash = {"id" => item.id.to_s, "label" => item.send(method), "value" => item.send(method)}
        extra_data.each do |datum|
          hash[datum] = item.send(datum)
        end if extra_data
        # TODO: Come back to remove this if clause when test suite is better
        hash
      end
    end
  end
end

