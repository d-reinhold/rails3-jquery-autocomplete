module Rails3JQueryAutocomplete
  module Orm
    module ActiveRecord
      def get_autocomplete_order(method, options, model=nil)
        order = options[:order]

        table_prefix = model ? "#{model.table_name}." : ""
        order || "#{table_prefix}#{method.first} ASC"
      end

      def get_autocomplete_items(parameters)
        model   = parameters[:model]
        term    = parameters[:term]
        method  = Array(parameters[:method])
        options = parameters[:options]
        scopes  = Array(options[:scopes])
        limit   = get_autocomplete_limit(options)
        order   = get_autocomplete_order(method, options, model)
        add_fields = parameters[:add_fields]
       
        items = model.scoped

        scopes.each { |scope| items = items.send(scope) } unless scopes.empty?


        if model == :course.to_s.camelize.constantize
          items = get_custom_autocomplete_items(model, term, method, options, add_fields)
        else 
          items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
          where_clause = get_autocomplete_where_clause(model, term, method, options, add_fields)
          items = items.where(where_clause).limit(limit).order(order)
        end
        return items
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{table_name}.#{method.first}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options, add_fields)
        table_name = model.table_name
        is_full_search = options[:full]
        like_clause = (postgres? ? 'ILIKE' : 'LIKE')


        rep = [method.map{|m| "LOWER(#{table_name}.#{m}) #{like_clause} ? " }.join('or ')]
        method.map{|m|
          rep << "#{(is_full_search ? '%' : '')}#{term.downcase}%"
        }
        rep
      end
      
      def get_custom_autocomplete_items(model, term, method, options, add_fields)
        table_name = model.table_name
        is_full_search = options[:full]
        like_clause = (postgres? ? 'ILIKE' : 'LIKE')
        
        add_restraints = add_fields.map{ |f| "school_symbol ilike '#{f}' "}.join('or ')
        
        terms = term.split(' ')
        
        puts "Terms:"
        terms.each{|t| puts t}
        
        # find course numbers
        # find departments (2-4 letter)
        course_numbers = []
        puts "Potential Course Numbers:"
        terms.reject! do |t|
          if t =~ /\d+/
            puts t
            course_numbers << t
          end
          t =~ /\d+/
        end
        
        depts = []
        puts "Potential Departments: "
        terms.each do |t|
          if t =~ /[a-zA-Z]+/ and t.length.between?(2,4)
            puts t
            depts << t
          end
        end
        
        best_match = []
        if course_numbers.any?
          puts "May have gotten a course number in the search terms!"
          best_match << "(" + course_numbers.map{|n| "number like ? "}.join('or ') + ")"
          if depts.any?
            puts "May have gotten a department in the search terms!"
            best_match[0] += " and " + "(" + depts.map{|d| "department ilike ? "}.join('or ') + ")" 
          end
        else
          if depts.any?
            puts "May have gotten a department in the search terms!"
            best_match << "(" + depts.map{|d| "department ilike ? "}.join('or ') + ")"
          end
        end
        
        puts "Remaining terms:"
        terms.each { |t| puts t}
        
        
        if best_match.any?
          puts best_match
          if add_fields.any? and 
            best_match[0] += " and ( " + add_restraints + " )" 
          end
        
          course_numbers.each{|n| best_match << "%#{n}%"}
          depts.each{|d| best_match << "%#{d}%"}
        
          best_result = Course.where(best_match)
        
          if best_result.any?
            puts "Got a good result: "
            return best_result
          end
        end
        
        
        or_clause = method.map{ |m| "LOWER(#{table_name}.#{m}) #{like_clause} ? "}.join('or ')
        puts "or clause: " + or_clause
        rep = []
        rep << "(" + or_clause + ")"
        rep[0] += " and ( " + add_restraints + " )" if add_fields.any?
        

        
        method.map{|m|
          rep << "#{(is_full_search ? '%' : '')}#{term.downcase}%"
        }
        
        result = Course.where(rep)
        return result
      end

      def postgres?
        defined?(PGconn)
      end
    end
  end
end










