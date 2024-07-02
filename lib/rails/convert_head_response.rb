# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_head_response' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It replaces render head response in controller files.

    ```ruby
    render nothing: true
    render nothing: true, status: :created

    head status: 406
    head location: '/foo'
    ```

    =>

    ```ruby
    head :ok
    head :created

    head 406
    head :ok, location: '/foo'
    ```
  EOS

  if_gem 'actionpack', '>= 5.0'

  within_file Synvert::RAILS_CONTROLLER_FILES do
    # render nothing: true
    # render nothing: true, status: :created
    # =>
    # head :ok
    # head :created
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'render',
              arguments: {
                node_type: 'arguments_node',
                arguments: { size: 1, first: { node_type: 'keyword_hash_node', nothing_value: true } }
              } do
      group do
        replace :message, with: 'head'
        if node.arguments.arguments.first.status_value.nil?
          replace 'arguments.arguments.0', with: ':ok'
        else
          replace 'arguments.arguments.0', with: '{{arguments.arguments.0.status_source}}'
        end
      end
    end

    # head location: '/foo'
    # =>
    # head :ok, location: '/foo'
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'head',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  first: { node_type: 'keyword_hash_node', location_value: { not: nil } }
                }
              } do
      replace 'arguments.arguments.0', with: ':ok, {{arguments.arguments.0.to_source}}'
    end

    # head status: 406
    # =>
    # head 406
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'head',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  first: { node_type: 'keyword_hash_node', status_value: { not: nil } }
                }
              } do
      replace 'arguments.arguments.0', with: '{{arguments.arguments.0.status_source}}'
    end
  end
end
