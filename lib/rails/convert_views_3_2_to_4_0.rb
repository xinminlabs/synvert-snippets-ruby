# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_views_3_2_to_4_0' do
  configure(parser: Synvert::PARSER_PARSER)

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
    within_node node_type: 'send',
                message: 'link_to',
                arguments: {
                  last: {
                    node_type: 'hash',
                    confirm_value: { not: nil },
                    data_value: nil
                  }
                } do
      group do
        delete 'arguments.last.confirm_pair', and_comma: true
        insert 'data: { confirm: {{arguments.last.confirm_value}} }', to: 'arguments.last', and_comma: true
      end
    end

    within_node node_type: 'send',
                message: 'link_to',
                arguments: {
                  last: {
                    node_type: 'hash',
                    confirm_value: { not: nil },
                    data_value: { not: nil }
                  }
                } do
      group do
        delete 'arguments.last.confirm_pair', and_comma: true
        insert 'confirm: {{arguments.last.confirm_value}}', to: 'arguments.last.data_pair.value.pairs', and_comma: true
      end
    end
  end
end
