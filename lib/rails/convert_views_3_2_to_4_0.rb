# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_views_3_2_to_4_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails views from 3.2 to 4.0.

    ```ruby
    link_to 'delete', post_path(post), confirm: 'Are you sure to delete post?'
    ```

    =>

    ```ruby
    link_to 'delete', post_path(post), data: { confirm: 'Are you sure to delete post?' }
    ```
  EOS

  if_gem 'actionview', '>= 4.0'

  within_files Synvert::RAILS_VIEW_FILES do
    # link_to 'delete', post_path(post), confirm: 'Are you sure to delete post?'
    # =>
    # link_to 'delete', post_path(post), data: { confirm: 'Are you sure to delete post?' }
    within_node node_type: 'call_node',
                name: 'link_to',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    last: { node_type: 'keyword_hash_node', confirm_value: { not: nil }, data_value: nil }
                  }
                } do
      group do
        delete 'arguments.arguments.last.confirm_element', and_comma: true
        insert 'data: { confirm: {{arguments.arguments.last.confirm_value}} }',
               to: 'arguments.arguments.last',
               and_comma: true
      end
    end

    within_node node_type: 'call_node',
                name: 'link_to',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    last: { node_type: 'keyword_hash_node', confirm_value: { not: nil }, data_value: { not: nil } }
                  }
                } do
      group do
        delete 'arguments.arguments.last.confirm_element', and_comma: true
        insert '{{arguments.arguments.last.confirm_element}}',
               to: 'arguments.arguments.last.data_element.value.elements',
               and_comma: true
      end
    end
  end
end
