# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'test_request_methods_use_keyword_arguments' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It converts rails test request methods to use keyword arguments

    functional test:

    ```ruby
    get :show, options
    ```

    =>

    ```ruby
    get :show, **options
    ```

    integration test:

    ```ruby
    get '/posts/1', options
    ```

    =>

    ```ruby
    get '/posts/1', **options
    ```
  EOS

  if_ruby '2.7'
  if_gem 'rails', '>= 5.2'

  request_methods = %i[get post put patch delete]

  # get :show, options
  # =>
  # get :show, **options
  within_files Synvert::RAILS_CONTROLLER_TEST_FILES + Synvert::RAILS_INTEGRATION_TEST_FILES do
    with_node node_type: 'send', message: { in: request_methods }, arguments: { size: 2, '-1': { node_type: { in: ['lvar', 'ivar'] } } } do
      insert '**', to: 'arguments.-1', at: 'beginning'
    end
  end
end
