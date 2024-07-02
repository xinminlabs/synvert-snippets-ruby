# frozen_string_literal: true

Synvert::Helper.new 'rails/set_load_defaults' do |options|
  configure(parser: Synvert::PRISM_PARSER)

  rails_version = options[:rails_version]

  within_file 'config/application.rb' do
    with_node node_type: 'class_node', constant_path: 'Application' do
      exists = false
      with_node node_type: 'call_node',
                receiver: 'config',
                name: 'load_defaults',
                arguments: { arguments: { length: 1 } } do
        exists = true
        replace_with "config.load_defaults #{rails_version}"
      end
      unless exists
        prepend "config.load_defaults #{rails_version}"
      end
    end
  end
end
