# frozen_string_literal: true

Synvert::Helper.new 'rails/parse' do |_options|
  configure(parser: Synvert::PRISM_PARSER)

  # Set number_of_workers to 1 to skip parallel.
  with_configurations(number_of_workers: 1) do
    tables = {}
    within_file 'db/schema.rb' do
      within_node node_type: 'call_node', name: 'create_table'  do
        table_name = node.arguments.arguments.first.to_value
        tables[table_name] = { columns: [], indices: [] }
        with_node node_type: 'call_node', receiver: 't', message: { not: 'index' } do
          column_name = node.arguments.arguments.first.to_value
          column_type = node.name.to_s
          tables[table_name][:columns] << { name: column_name, type: column_type }
        end
        with_node node_type: 'call_node', receiver: 't', message: 'index' do
          index_columns = node.arguments.arguments.first.to_value
          index_name = node.arguments.arguments.second.name_value.to_value
          tables[table_name][:indices] << { columns: index_columns, name: index_name }
        end
      end
    end
    # rails_tables
    # {
    #   "users" => {
    #     columns: [{ name: "email", type: "string" }, { name: "login", type: "string" }],
    #     indices: [{ columns: ["email"], name: "index_users_on_email" }]
    #   }
    # }
    save_data(:rails_tables, tables)

    associations = []
    context_stack = []

    within_files Synvert::RAILS_MODEL_FILES do
      add_callback :module_node, at: 'start' do |node|
        name = node.constant_path.to_source
        context_stack.push(name)
      end

      add_callback :module_node, at: 'end' do |node|
        context_stack.pop
      end

      add_callback :class_node, at: 'start' do |node|
        name = node.constant_path.to_source
        context_stack.push(name)
      end

      add_callback :class_node, at: 'end' do |node|
        context_stack.pop
      end

      add_callback :call_node, at: 'start' do |node|
        if node.receiver.nil? && %i[belongs_to has_one has_many has_and_belongs_to_many].include?(node.name)
          association_name = node.arguments.arguments.first.to_value
          options = {}
          if node.arguments.arguments.length > 1 && node.arguments.arguments.last.is_a?(Prism::KeywordHashNode)
            option_elements = node.arguments.arguments.last.elements
            %i[foreign_key foreign_type polymorphic].each do |option_key|
              option_element = option_elements.find { |element| element.key.value == option_key.to_s }
              options[option_key] = option_element.value.to_value if option_element
            end
          end
          associations << { class_name: context_stack.join('::'), name: association_name.to_s, type: node.name.to_s, **options }
        end
      end
    end
    # rails_models
    # {
    #   associations: [
    #     { class_name: "Polymorphic", name: "imageable", type: "belongs_to", polymorphic: true }
    #     { class_name: "User", name: "organization", type: "belongs_to" },
    #     { class_name: "User", name: "posts", type: "has_many" }
    #   ]
    # }
    save_data(:rails_models, associations: associations)
  end
end
