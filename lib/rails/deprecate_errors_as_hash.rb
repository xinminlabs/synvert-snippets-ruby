# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'deprecate_errors_as_hash' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It deprecates errors as hash.

    ```ruby
    book.errors[:title] << 'is not interesting enough.'
    book.errors.values
    book.errors.keys
    ```

    =>

    ```ruby
    book.errors.add(:title, 'is not interesting enough.')
    book.errors.map(&:full_message)
    book.errors.map(&:attrobite)
    ```
  EOS

  if_gem 'activemodel', '>= 6.1'

  within_files Synvert::ALL_RUBY_FILES do
    with_node node_type: 'send',
              receiver: {
                node_type: 'send',
                receiver: { node_type: 'send', message: 'errors', arguments: { size: 0 } },
                message: '[]',
                arguments: { size: 1 }
              },
              message: '<<',
              arguments: { size: 1 } do
      replace_with '{{receiver.receiver}}.add({{receiver.arguments.0}}, {{arguments.0}})'
    end

    with_node node_type: 'send',
              receiver: { node_type: 'send', message: 'errors', arguments: { size: 0 } },
              message: 'values',
              arguments: { size: 0 } do
      replace_with '{{receiver}}.map(&:message)'
    end

    with_node node_type: 'send',
              receiver: { node_type: 'send', message: 'errors', arguments: { size: 0 } },
              message: 'keys',
              arguments: { size: 0 } do
      replace_with '{{receiver}}.map(&:attribute)'
    end
  end
end