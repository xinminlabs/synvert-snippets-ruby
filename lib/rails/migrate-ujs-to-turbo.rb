# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'migrate-ujs-to-turbo' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It migrates rails ujs to turbo.

    ```ruby
    <%= link_to "Destroy", post_path(post), method: :delete %>
    <%= link_to "Destroy", post_path(post), method: :delete, data: { confirm: 'Are you sure?' } %>
    <%= submit_tag "Create", data: { disable_with: "Submitting..." } %>
    ```

    =>

    ```ruby
    <%= link_to "Destroy", post_path(post), data: { turbo_method: :delete } %>
    <%= link_to "Destroy", post_path(post), data: { turbo_method: :delete, turbo_confirm: 'Are you sure?' } %>
    <%= submit_tag "Create", data: { turbo_submits_with: "Submitting..." } %>
    ```
  EOS

  within_files Synvert::RAILS_VIEW_FILES do
    # link_to "Destroy", post_path(post), method: :delete, data: { confirm: 'Are you sure?' }
    # link_to "Destroy", post_path(post), data: { turbo_method: :delete }
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'link_to',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 3,
                  last: {
                    node_type: 'keyword_hash_node',
                    method_value: :delete,
                    data_value: { node_type: 'hash_node', confirm_value: { not: nil } }
                  }
                }
              } do
      delete 'arguments.arguments.-1.method_element', and_comma: true
      insert 'turbo_method: {{arguments.arguments.-1.method_source}}',
             to: 'arguments.arguments.-1.data_value.elements.0',
             at: 'beginning',
             and_comma: true
      replace 'arguments.arguments.-1.data_value.confirm_element.key', with: 'turbo_confirm:'
    end

    # link_to "Destroy", post_path(post), method: :delete
    # =>
    # link_to "Destroy", post_path(post), data: { turbo_method: :delete }
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'link_to',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 3,
                  last: { node_type: 'keyword_hash_node', method_value: :delete, data_value: nil }
                }
              } do
      delete 'arguments.arguments.-1.method_element', and_comma: true
      insert 'data: { turbo_method: {{arguments.arguments.-1.method_source}} }',
             to: 'arguments.arguments.-1',
             at: 'end',
             and_comma: true
    end

    # submit_tag "Create", data: { disable_with: "Submitting..." }
    # =>
    # submit_tag "Create", data: { turbo_submits_with: "Submitting..." }
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'submit_tag',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  last: {
                    node_type: 'keyword_hash_node',
                    data_value: { node_type: 'hash_node', disable_with_value: { not: nil } }
                  }
                }
              } do
      replace "arguments.arguments.1.data_value.disable_with_element.key", with: 'turbo_submits_with:'
    end
  end
end
