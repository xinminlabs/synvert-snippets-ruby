# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_rails_env' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts RAILS_ENV to Rails.env.

    ```ruby
    RAILS_ENV
    \"\#{RAILS_ENV}\"
    RAILS_ENV == 'development'
    'development' == RAILS_ENV
    RAILS_ENV != 'development'
    'development' != RAILS_ENV
    ```

    =>

    ```ruby
    Rails.env
    \"\#{Rails.env}\"
    Rails.env.development?
    Rails.env.development?
    !Rails.env.development?
    !Rails.env.development?
    ```
  EOS

  if_gem 'rails', '>= 2.3'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # RAILS_ENV == 'test'
    # =>
    # Rails.env == 'test'
    with_node node_type: 'constant_read_node', name: 'RAILS_ENV' do
      replace_with 'Rails.env'
    end
  end

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # Rails.env == 'test'
    # =>
    # Rails.env.test?
    with_node node_type: 'call_node',
              receiver: 'Rails.env',
              name: '==',
              arguments: { node_type: 'arguments_node', arguments: { size: 1 } } do
      replace_with "Rails.env.{{arguments.arguments.0.to_value}}?"
    end

    # 'development' == Rails.env
    # =>
    # Rails.env.development?
    with_node node_type: 'call_node',
              name: '==',
              arguments: { node_type: 'arguments_node', arguments: { size: 1, first: 'Rails.env' } } do
      replace_with "Rails.env.{{receiver.to_value}}?"
    end

    # Rails.env != 'test'
    # =>
    # !Rails.env.test?
    with_node node_type: 'call_node',
              receiver: 'Rails.env',
              name: '!=',
              arguments: { node_type: 'arguments_node', arguments: { size: 1 } } do
      replace_with "!Rails.env.{{arguments.arguments.0.to_value}}?"
    end

    # 'development' != Rails.env
    # =>
    # !Rails.env.development?
    with_node node_type: 'call_node',
              name: '!=',
              arguments: { node_type: 'arguments_node', arguments: { size: 1, first: 'Rails.env' } } do
      replace_with "!Rails.env.{{receiver.to_value}}?"
    end
  end
end
