# frozen_string_literal: true

Synvert::Rewriter.new 'minitest', 'assert_nil' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    Use `assert_nil` if expecting `nil`.

    ```ruby
    assert_equal(nil, actual)
    ```

    =>

    ```ruby
    assert_nil(actual)
    ```
  EOS

  within_files Synvert::RAILS_MINITEST_FILES do
    find_node '.send[receiver=nil][message=assert_equal][arguments.size=2][arguments.first=nil]' do
      group do
        replace :message, with: 'assert_nil'
        delete 'arguments.first', and_comma: true
      end
    end
  end
end
