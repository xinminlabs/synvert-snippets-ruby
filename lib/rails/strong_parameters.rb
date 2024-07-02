# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'strong_parameters' do
  configure(parser: Synvert::PRISM_PARSER)

  default_columns = %w[id created_at updated_at deleted_at]

  description <<~EOS
    It uses string_parameters to replace `attr_accessible`.

    1. it removes active_record configurations.

    ```ruby
    config.active_record.whitelist_attributes = ...
    config.active_record.mass_assignment_sanitizer = ...
    ```

    2. it removes `attr_accessible` and `attr_protected` code in models.

    3. it adds xxx_params in controllers

    ```ruby
    def xxx_params
      params.require(:xxx).permit(...)
    end
    ```

    4. it replaces params[:xxx] with xxx_params.

    ```ruby
    params[:xxx] => xxx_params
    ```
  EOS

  if_gem 'rails', '>= 4.0'

  within_files 'config/**/*.rb' do
    # remove config.active_record.whitelist_attributes = ...
    with_node node_type: 'call_node',
              receiver: {
                node_type: 'call_node',
                receiver: 'config',
                name: 'active_record'
              },
              name: 'whitelist_attributes=' do
      remove
    end

    # remove config.active_record.mass_assignment_sanitizer = ...
    with_node node_type: 'call_node',
              receiver: {
                node_type: 'call_node',
                receiver: 'config',
                name: 'active_record'
              },
              name: 'mass_assignment_sanitizer=' do
      remove
    end
  end

  call_helper 'rails/parse'
  rails_tables = load_data :rails_tables

  parameters = {}
  within_files Synvert::RAILS_MODEL_FILES do
    within_node node_type: 'class_node' do
      object_name = node.name.to_s.underscore
      table_columns =
        rails_tables.present? ? rails_tables[object_name.tableize][:columns].map { |column|
                                  column[:name]
                                } - default_columns : []

      # assign and remove attr_accessible ...
      with_node node_type: 'call_node', name: 'attr_accessible' do
        parameters[object_name] = node.arguments.arguments.map(&:to_source)
        remove
      end

      # assign and remove attr_protected ...
      with_node node_type: 'call_node', name: 'attr_protected' do
        parameters[object_name] = table_columns.map { |column|
          ":#{column}"
        } - node.arguments.arguments.map(&:to_source)
        remove
      end
    end
  end

  within_file Synvert::RAILS_CONTROLLER_FILES do
    within_node node_type: 'class_node' do
      object_name = node.name.to_s.sub('Controller', '').singularize.underscore
      if_exist_node node_type: 'call_node',
                    receiver: 'params',
                    name: '[]',
                    arguments: { node_type: 'arguments_node', arguments: [object_name.to_sym] } do
        if parameters[object_name]
          # append def xxx_params; ...; end
          permit_params = parameters[object_name].join(', ')
          unless_exist_node node_type: 'def_node', name: "#{object_name}_params" do
            append <<~EOS
              def #{object_name}_params
                params.require(:#{object_name}).permit(#{permit_params})
              end
            EOS
          end

          # params[:xxx] => xxx_params
          with_node node_type: 'call_node', receiver: 'params', name: '[]' do
            object_name = node.arguments.arguments.first.to_value.to_s
            if parameters[object_name]
              replace_with "#{object_name}_params"
            end
          end
        end
      end
    end
  end
end
