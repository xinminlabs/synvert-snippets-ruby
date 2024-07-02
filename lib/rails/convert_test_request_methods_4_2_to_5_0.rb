# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_test_request_methods_4_2_to_5_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails test request methods from 4.2 to 5.0

    functional test:

    ```ruby
    get :show, { id: user.id, format: :json }, { admin: user.admin? }, { notice: 'Welcome' }
    ```

    =>

    ```ruby
    get :show, params: { id: user.id }, session: { admin: user.admin? }, flash: { notice: 'Welcome' }, as: :json
    ```

    integration test:

    ```ruby
    get '/posts/1', { user_id: user.id }, { 'HTTP_AUTHORIZATION' => 'fake' }
    ```

    =>

    ```ruby
    get '/posts/1', params: { user_id: user.id }, headers: { 'HTTP_AUTHORIZATION' => 'fake' }
    ```
  EOS

  if_gem 'rails', '>= 5.0'

  request_methods = %i[get post put patch delete]

  helper_method :make_up_hash_element do |key, argument_node|
    next if argument_node.to_source == 'nil'

    if argument_node.type == :keyword_hash_node || argument_node.type == :hash_node
      new_value =
        argument_node.elements.reject { |element_node|
          element_node.type == :assoc_node && %i[format xhr as].include?(element_node.key.to_value)
        }
.map(&:to_source).join(', ')
      "#{key}: #{add_curly_brackets_if_necessary(new_value)}" if new_value.length > 0
    else
      "#{key}: #{argument_node.to_source}"
    end
  end

  # get :show, { id: user.id }, { notice: 'Welcome' }, { admin: user.admin? }
  # =>
  # get :show, params: { id: user.id }, flash: { notice: 'Welcome' }, session: { admin: user.admin? }.
  within_files Synvert::RAILS_CONTROLLER_TEST_FILES do
    with_node node_type: 'call_node',
              name: { in: request_methods },
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: { gt: 1 },
                  '1': { node_type: { in: ['keyword_hash_node', 'hash_node'] }, params_value: nil }
                }
              } do
      # skip if element of hash node is assoc_splat_node
      next if node.arguments.arguments[1].elements.any? { |element| element.type != :assoc_node }

      format_value = node.arguments.arguments[1].format_value || node.arguments.arguments[1].as_value
      xhr_value = node.arguments.arguments[1].xhr_value
      options = []
      options << make_up_hash_element('params', node.arguments.arguments[1])
      options << make_up_hash_element('session', node.arguments.arguments[2]) if node.arguments.arguments.size > 2
      options << make_up_hash_element('flash', node.arguments.arguments[3]) if node.arguments.arguments.size > 3
      options << "as: #{format_value.to_source}" if format_value
      options << "xhr: #{xhr_value.to_source}" if xhr_value
      replace :arguments, with: "{{arguments.arguments.0}}, #{options.compact.join(', ')}"
    end

    with_node node_type: 'call_node', name: 'xhr', arguments: { node_type: 'arguments_node', arguments: { size: 2 } } do
      replace :message, with: '{{arguments.arguments.0.to_string}}'
      replace :arguments, with: '{{arguments.arguments.1}}, xhr: true'
    end

    with_node node_type: 'call_node',
              name: 'xhr',
              arguments: { node_type: 'arguments_node', arguments: { size: { gt: 2 } } } do
      format_value = node.arguments.arguments[2].type == :hash && node.arguments.arguments[2].format_value
      options = []
      options << make_up_hash_element('params', node.arguments.arguments[2])
      options << make_up_hash_element('session', node.arguments.arguments[3]) if node.arguments.arguments.size > 3
      options << make_up_hash_element('flash', node.arguments.arguments[4]) if node.arguments.arguments.size > 4
      options << "as: #{format_value.to_source}" if format_value
      replace :message, with: '{{arguments.arguments.0.to_string}}'
      replace :arguments, with: "{{arguments.arguments.1}}, #{options.compact.join(', ')}, xhr: true"
    end
  end

  # get '/posts/1', user_id: user.id, { 'HTTP_AUTHORIZATION' => 'fake' }
  # =>
  # get '/posts/1', params: { user_id: user.id }, headers: { 'HTTP_AUTHORIZATION' => 'fake' }
  within_files Synvert::RAILS_INTEGRATION_TEST_FILES do
    with_node node_type: 'call_node',
              name: { in: request_methods },
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: { gt: 1 },
                  '1': { node_type: { in: ['keyword_hash_node', 'hash_node'] }, params_value: nil, headers_value: nil }
                }
              } do
      options = []
      options << make_up_hash_element('params', node.arguments.arguments[1])
      options << make_up_hash_element('headers', node.arguments.arguments[2]) if node.arguments.arguments.size > 2
      replace :arguments, with: "{{arguments.arguments.0}}, #{options.compact.join(', ')}"
    end

    with_node node_type: 'call_node',
              name: { in: request_methods },
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: { gt: 1 },
                  '1': nil,
                  '2': { node_type: { in: ['keyword_hash_node', 'hash_node'] } }
                }
              } do
      delete 'arguments.arguments.1', and_comma: true
      insert 'headers: ', to: 'arguments.arguments.2', at: 'beginning'
    end
  end
end
