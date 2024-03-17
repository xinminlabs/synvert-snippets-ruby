# frozen_string_literal: true

Synvert::Helper.new 'rails/parse' do |options|
  configure(parser: Synvert::PRISM_PARSER)

  # Set number_of_workers to 1 to skip parallel.
  with_configurations(number_of_workers: 1) do
    tables = {}
    within_file 'db/schema.rb' do
      within_node node_type: 'call_node', name: 'create_table' do
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
  end
end
