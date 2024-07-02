# frozen_string_literal: true

Synvert::Rewriter.new 'ruby', 'use_keyword_arguments' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It tries to convert ruby code to use keyword arguments.

    ```ruby
    CSV.generate(options) do |csv|
    end
    ```
    =>
    ```ruby
    CSV.generate(**options) do |csv|
    end
    ```
  EOS

  if_ruby '2.7'

  # CSV.generate(options) do |csv|
  # end
  # =>
  # CSV.generate(**options) do |csv|
  # end
  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    with_node node_type: 'call_node',
              receiver: 'CSV',
              name: 'generate',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  '0': {
                    node_type: {
                      in: %w[
                        local_variable_read_node
                        instance_variable_read_node
                        call_node
                      ]
                    }
                  }
                }
              } do
      insert '**', to: 'arguments.arguments.0', at: 'beginning'
    end
  end
end
