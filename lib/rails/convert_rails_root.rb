# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_rails_root' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts RAILS_ROOT to Rails.root.

    ```ruby
    RAILS_ROOT
    File.join(RAILS_ROOT, 'config/database.yml')
    RAILS_ROOT + 'config/database.yml'
    "\#{RAILS_ROOT}/config/database.yml"
    File.exists?(Rails.root.join('config/database.yml'))
    ```

    =>

    ```ruby
    Rails.root
    Rails.root.join('config/database.yml')
    Rails.root.join('config/database.yml')
    Rails.root.join('config/database.yml')
    Rails.root.join('config/database.yml').exist?
    ```
  EOS

  if_gem 'rails', '>= 2.3'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # RAILS_ROOT => Rails.root
    with_node node_type: 'constant_read_node', name: 'RAILS_ROOT' do
      replace_with 'Rails.root'
    end
  end

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # File.join(Rails.root, 'config/database.yml')
    # =>
    # Rails.root.join('config/database.yml')
    with_node node_type: 'call_node',
              receiver: 'File',
              name: 'join',
              arguments: { node_type: 'arguments_node', arguments: { first: 'Rails.root' } } do
      other_arguments = node.arguments.arguments[1..-1].map(&:to_source).join(', ')
      replace_with "Rails.root.join(#{other_arguments})"
    end

    # Rails.root + '/config/database.yml'
    # =>
    # Rails.root.join('config/database.yml')
    with_node node_type: 'call_node', receiver: 'Rails.root', name: '+' do
      other_argument_str = node.arguments.arguments.first.to_source
      other_argument_str[1] = '' if '/' == other_argument_str[1]
      replace_with "Rails.root.join(#{other_argument_str})"
    end

    # "#{Rails.root}/config/database.yml"
    # =>
    # Rails.root.join('config/database.yml')
    with_node node_type: 'interpolated_string_node',
              parts: {
                first: {
                  node_type: 'embedded_statements_node',
                  statements: { body: { first: 'Rails.root' } }
                }
              } do
      source = node.to_source
      source[1..14] = ''
      replace_with "Rails.root.join(#{source})"
    end
  end

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # File.exists?(Rails.root.join('config/database.yml'))
    # =>
    # Rails.root.join('config/database.yml').exist?
    with_node node_type: 'call_node',
              receiver: 'File',
              name: 'exists?',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  first: {
                    node_type: 'call_node',
                    receiver: 'Rails.root',
                    name: 'join'
                  }
                }
              } do
      replace_with '{{arguments.arguments.first}}.exist?'
    end
  end
end
