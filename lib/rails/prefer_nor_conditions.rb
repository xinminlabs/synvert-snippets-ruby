# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'prefer_nor_conditions' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    Prefer NOR conditions

    ```ruby
    where.not(first_name: nil, last_name: nil)
    ```

    =>

    ```ruby
    where.not(first_name: nil).where.not(last_name: nil)
    ```
  EOS

  if_gem 'rails', '>= 6.0'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    with_node node_type: 'call_node',
              receiver: { node_type: 'call_node', name: 'where', arguments: nil },
              name: 'not',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  first: { node_type: 'keyword_hash_node', elements: { length: { gt: 1 } } }
                }
              } do
      new_source = node.arguments.arguments.first.elements.map { |element| "where.not(#{element.to_source})" }
                       .join('.')
      replace 'receiver.message', :closing, with: new_source
    end
  end
end
