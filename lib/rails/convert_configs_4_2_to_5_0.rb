# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_configs_4_2_to_5_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails configs 4.2 to 5.0

    1. it sets `config.load_defaults 5.0` in config/application.rb.

    2. it replaces `config.static_cache_control = ...` with `config.public_file_server.headers = ...` in config files.

    3. it replaces `config.serve_static_files = ...` with `config.public_file_server.enabled = ...` in config files.

    4. it replaces `middleware.use "Foo::Bar"` with `middleware.use Foo::Bar` in config files.

    5. it adds config/initializers/new_framework_defaults.rb.

    6. it removes `raise_in_transactional_callbacks=` in config/application.rb.
  EOS

  if_gem 'rails', '~> 5.0.0'

  call_helper 'rails/set_load_defaults', rails_version: '5.0'

  within_file 'config/application.rb' do
    # remove config.raise_in_transactional_callbacks = true
    with_node node_type: 'call_node', name: 'raise_in_transactional_callbacks=' do
      remove
    end
  end

  within_files 'config/environments/*.rb' do
    # config.static_cache_control = 'public, max-age=31536000'
    # =>
    # config.public_file_server.headers = { "Cache-Control" => 'public, max-age=31536000' }
    with_node node_type: 'call_node', name: 'static_cache_control=' do
      replace_with '{{receiver}}.public_file_server.headers = { "Cache-Control" => {{arguments}} }'
    end

    # config.serve_static_files = true
    # =>
    # config.public_file_server.enabled = true
    with_node node_type: 'call_node', name: 'serve_static_files=' do
      replace :message, with: 'public_file_server.enabled'
    end

    # config.middleware.use "Foo::Bar"
    # =>
    # config.middleware.use Foo::Bar
    with_node node_type: 'call_node',
              receiver: {
                node_type: 'call_node',
                receiver: 'config',
                name: 'middleware'
              },
              name: 'use',
              arguments: {
                node_type: 'arguments_node',
                arguments: { size: { gt: 0 }, first: { node_type: 'string_node' } }
              } do
      replace 'arguments.arguments.first', with: "{{arguments.arguments.first.to_value}}"
    end
  end

  new_code = <<~EOS.strip
    # Be sure to restart your server when you modify this file.
    #
    # This file contains migration options to ease your Rails 5.0 upgrade.
    #
    # Read the Guide for Upgrading Ruby on Rails for more info on each option.

    # Enable per-form CSRF tokens. Previous versions had false.
    Rails.application.config.action_controller.per_form_csrf_tokens = true

    # Enable origin-checking CSRF mitigation. Previous versions had false.
    Rails.application.config.action_controller.forgery_protection_origin_check = true

    # Make Ruby 2.4 preserve the timezone of the receiver when calling `to_time`.
    # Previous versions had false.
    ActiveSupport.to_time_preserves_timezone = true

    # Require `belongs_to` associations by default. Previous versions had false.
    Rails.application.config.active_record.belongs_to_required_by_default = true

    # Do not halt callback chains when a callback returns false. Previous versions had true.
    ActiveSupport.halt_callback_chains_on_return_false = false

    # Configure SSL options to enable HSTS with subdomains. Previous versions had false.
    Rails.application.config.ssl_options = { hsts: { subdomains: true } }
  EOS
  add_file 'config/initializers/new_framework_defaults.rb', new_code
end
