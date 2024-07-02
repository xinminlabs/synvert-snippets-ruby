# frozen_string_literal: true

Synvert::Helper.new 'ruby/parse' do |options|
  configure(parser: Synvert::PRISM_PARSER)

  # Set number_of_workers to 1 to skip parallel.
  with_configurations(number_of_workers: 1) do
    definitions = { modules: [], classes: [], constants: [] }
    current_context = definitions
    context_stack = [current_context]

    helper_method :find_in_definitions do |names, definitions|
      return nil if names.empty? || definitions.nil?

      if names.length > 1
        # The first name is a module, find it and search within its definitions
        mod_name = names.shift
        definitions[:modules].each do |mod|
          if mod[:name] == mod_name
            return find_in_definitions(names, mod) # Recurse with the rest of the names
          end
        end
      else
        # The last name is a class, find it in the current definitions
        class_name = names.first
        definitions[:classes].each do |klass|
          return klass if klass[:name] == class_name
        end
        definitions[:modules].each do |mod|
          found = find_in_definitions([class_name], mod)
          return found if found
        end
      end

      nil
    end

    helper_method :find_class do |full_name, definitions|
      names = full_name.split('::')
      find_in_definitions(names, definitions)
    end

    within_file Synvert::ALL_RUBY_FILES do
      add_callback :module_node, at: 'start' do |node|
        name = node.constant_path.to_source
        existing_module = current_context[:modules].find { |mod| mod[:name] == name }
        if existing_module
          new_context = existing_module
        else
          full_name = [current_context[:full_name], name].compact.join('::')
          new_context = {
            name: name,
            full_name: full_name,
            type: "module",
            modules: [],
            classes: [],
            methods: [],
            static_methods: [],
            singleton: {},
            constants: []
          }
          current_context[:modules] << new_context
        end

        context_stack.push(new_context)
        current_context = new_context
      end

      add_callback :module_node, at: 'end' do |node|
        context_stack.pop
        current_context = context_stack.last
      end

      add_callback :class_node, at: 'start' do |node|
        name = node.constant_path.to_source
        superclass = node.superclass&.to_source
        existing_class = current_context[:classes].find { |klass| klass[:name] == name }
        if existing_class
          new_context = existing_class
        else
          full_name = [current_context[:full_name], name].compact.join('::')
          new_context = {
            name: name,
            full_name: full_name,
            type: "class",
            superclass: superclass,
            modules: [],
            classes: [],
            methods: [],
            static_methods: [],
            singleton: {},
            constants: [],
            included_modules: []
          }
          current_context[:classes] << new_context
        end

        context_stack.push(new_context)
        current_context = new_context
      end

      add_callback :class_node, at: 'end' do |node|
        context_stack.pop
        current_context = context_stack.last
      end

      add_callback :singleton_class_node, at: 'start' do |node|
        existing_singleton = current_context[:singleton]
        if !existing_singleton.empty?
          new_context = existing_singleton
        else
          new_context = { type: 'singleton', methods: [], constants: [] }
          current_context[:singleton] = new_context
        end

        context_stack.push(new_context)
        current_context = new_context
      end

      add_callback :singleton_class_node, at: 'end' do |node|
        context_stack.pop
        current_context = context_stack.last
      end

      add_callback :constant_write_node do |node|
        current_context[:constants] << { name: node.name.to_s }
      end

      add_callback :call_node, at: 'start' do |node|
        if node.receiver.nil? && node.name == :include && current_context[:type] == "class" && !node.arguments.nil? && %i[
          constant_read_node constant_path_node
        ].include?(node.arguments.arguments.first.type)

          current_context[:included_modules] << node.arguments.arguments.first.to_source
        end
      end

      add_callback :call_node, at: 'start' do |node|
        # we can't handle the class_eval / included / class_methods
        if !node.receiver.nil? && %i[class_eval included class_methods].include?(node.name)
          throw(:abort)
        end
      end

      add_callback :def_node, at: 'start' do |node|
        # we can't handle `def self.inclueded` method
        if !node.receiver.nil? && node.name == :included
          throw(:abort)
        end
      end

      add_callback :def_node, at: 'start' do |node|
        throw(:abort) unless context_stack.last[:type]

        name = node.name.to_s
        new_context = { name: name }
        if node.receiver.nil?
          current_context[:methods] << new_context
        else
          current_context[:static_methods] << new_context
        end

        context_stack.push(new_context)
        current_context = new_context
      end

      add_callback :def_node, at: 'end' do |node|
        context_stack.pop
        current_context = context_stack.last
      end
    end

    def find_class(full_name, definitions)
      names = full_name.split('::')
      find_in_definitions(names, definitions)
    end

    def find_in_definitions(names, definitions)
      return nil if names.empty? || definitions.nil?

      if names.length > 1
        # The first name is a module, find it and search within its definitions
        mod_name = names.shift
        definitions[:modules].each do |mod|
          if mod[:name] == mod_name
            return find_in_definitions(names, mod) # Recurse with the rest of the names
          end
        end
      else
        # The last name is a class, find it in the current definitions
        class_name = names.first
        definitions[:classes].each do |klass|
          return klass if klass[:name] == class_name
        end
        definitions[:modules].each do |mod|
          found = find_in_definitions([class_name], mod)
          return found if found
        end
      end

      nil
    end

    def add_ancestors(definitions)
      definitions[:classes].each do |klass|
        ancestors = []
        superclass = klass[:superclass]
        while superclass
          superclass_class = find_class(superclass, definitions)
          if superclass_class
            ancestors << superclass_class[:full_name]
            ancestors.concat(superclass_class[:included_modules]) if superclass_class[:included_modules]
            superclass = superclass_class[:superclass]
          else
            ancestors << superclass
            superclass = nil
          end
        end
        ancestors.concat(klass[:included_modules]) if klass[:included_modules]
        klass[:ancestors] = ancestors

        add_ancestors(klass)
      end

      definitions[:modules].each do |mod|
        add_ancestors(mod)
      end
    end

    add_ancestors(definitions)

    save_data :ruby_definitions, definitions
  end
end
