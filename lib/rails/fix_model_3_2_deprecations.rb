# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'fix_model_3_2_deprecations' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It fixes rails 3.2 model deprecations.

    ```ruby
    set_table_name "project"
    ```

    =>

    ```ruby
    self.table_name = "project"
    ```

    ```ruby
    set_inheritance_column = "type"
    ```

    =>

    ```ruby
    self.inheritance_column = "type"
    ```

    ```ruby
    set_sequence_name = "seq"
    ```

    =>

    ```ruby
    self.sequence_name = "seq"
    ```

    ```ruby
    set_primary_key = "id"
    ```

    =>

    ```ruby
    self.primary_key = "id"
    ```

    ```ruby
    set_locking_column = "lock"
    ```

    =>

    ```ruby
    self.locking_column = "lock"
    ```
  EOS

  if_gem 'activerecord', '>= 3.2'

  within_files Synvert::RAILS_MODEL_FILES do
    # set_table_name "project" => self.table_name = "project"
    # set_inheritance_column = "type" => self.inheritance_column = "type"
    # set_sequence_name = "seq" => self.sequence_name = "seq"
    # set_primary_key = "id" => self.primary_key = "id"
    # set_locking_column = "lock" => self.locking_column = "lock"
    with_node node_type: 'call_node',
              name: {
                in: %w[
                  set_table_name
                  set_inheritance_column
                  set_sequence_name
                  set_primary_key
                  set_locking_column
                ]
              } do
      replace :message, with: "self.#{node.name.to_s.sub('set_', '')} ="
    end
  end
end
