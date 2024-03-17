# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_configs_3_0_to_3_1' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It upgrade rails configs from 3.0 to 3.1.

    1. it enables asset pipeline.

    ```ruby
    config.assets.enabled = true
    config.assets.version = '1.0'
    ```

    2. it removes `config.action_view.debug_rjs` in config/environments/development.rb

    3. it adds asset pipeline configs in config/environments/development.rb

    ```ruby
    # Do not compress assets
    config.assets.compress = false

    # Expands the lines which load the assets
    config.assets.debug = true
    ```

    4. it adds asset pipeline configs in config/environments/production.rb

    ```ruby
    # Compress JavaScripts and CSS
    config.assets.compress = true

    # Don't fallback to assets pipeline if a precompiled asset is missed
    config.assets.compile = false

    # Generate digests for assets URLs
    config.assets.digest = true
    ```

    5. it adds asset pipeline configs in config/environments/test.rb

    ```ruby
    # Configure static asset server for tests with Cache-Control for performance
    config.serve_static_assets = true
    config.static_cache_control = "public, max-age=3600"
    ```

    6. it creates config/environments/wrap_parameters.rb.

    7. it replaces session_store in config/initializers/session_store.rb

    ```ruby
    Application.session_store :cookie_store, key: '_xxx-session'
    ```

    8. Migrations now use instance methods rather than class methods

    ```ruby
    def self.up
    end

    def self.down
    end
    ```

    =>

    ```ruby
    def up
    end

    def down
    end
    ```
  EOS

  if_gem 'rails', '~> 3.1.0'

  within_file 'config/application.rb' do
    # prepend config.assets.version = '1.0'
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'version=' do
      prepend "config.assets.version = '1.0'"
    end

    # prepend config.assets.enabled = true
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'enabled=' do
      prepend 'config.assets.enabled = true'
    end
  end

  within_file 'config/environments/development.rb' do
    # remove config.action_view.debug_rjs = true
    with_node node_type: 'call_node',
              receiver: {
                node_type: 'call_node',
                receiver: 'config',
                name: 'action_view'
              },
              name: 'debug_rjs=' do
      remove
    end

    # prepend config.assets.debug = true
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'debug=' do
      prepend 'config.assets.debug = true'
    end

    # prepend config.assets.compress = false
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'compress=' do
      prepend 'config.assets.compress = false'
    end
  end

  within_file 'config/environments/production.rb' do
    # prepend config.assets.digest = true
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'digest=' do
      prepend 'config.assets.digest = true'
    end

    # prepend config.assets.compile = false
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'compile=' do
      prepend 'config.assets.compile = false'
    end

    # prepend config.assets.compress = true
    unless_exist_node node_type: 'call_node',
                      receiver: {
                        node_type: 'call_node',
                        receiver: 'config',
                        name: 'assets'
                      },
                      name: 'compress=' do
      prepend 'config.assets.compress = true'
    end
  end

  within_file 'config/environments/test.rb' do
    # prepend config.static_cache_control = "public, max-age=3600"
    unless_exist_node node_type: 'call_node', receiver: 'config', name: 'static_cache_control=' do
      prepend 'config.static_cache_control = "public, max-age=3600"'
    end

    # prepend config.serve_static_assets = true
    unless_exist_node node_type: 'call_node', receiver: 'config', name: 'serve_static_assets=' do
      prepend 'config.serve_static_assets = true'
    end
  end

  # add config/initializers/wrap_parameters.rb'
  add_file 'config/initializers/wrap_parameters.rb', <<~EOS
    # Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
    ActiveSupport.on_load(:action_controller) do
      wrap_parameters format: [:json]
    end

    # Disable root element in JSON by default.
    ActiveSupport.on_load(:active_record) do
      self.include_root_in_json = false
    end
  EOS

  within_file 'config/initializers/session_store.rb' do
    # add Application.session_store :cookie_store, key: '_xxx-session'
    with_node node_type: 'call_node',
              receiver: {
                node_type: 'call_node',
                name: 'config'
              },
              name: 'session_store',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  first: :cookie_store
                }
              } do
      session_store_key = node.receiver.receiver.to_source.split(':').first.underscore
      replace_with "{{receiver}}.session_store :cookie_store, key: '_#{session_store_key}-session'"
    end
  end
end
