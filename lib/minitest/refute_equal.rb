# frozen_string_literal: true

Synvert::Rewriter.new 'minitest', 'refute_equal' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    Use `refute_equal` if expected and actual should not be same.

    ```ruby
    assert("rubocop-minitest" != actual)
    assert(!"rubocop-minitest" == actual)
    ```

    =>

    ```ruby
    refute_equal("rubocop-minitest", actual)
    refute_equal("rubocop-minitest", actual)
    ```
  EOS

  within_files Synvert::RAILS_MINITEST_FILES do
    # assert("rubocop-minitest" != actual)
    # =>
    # refute_equal("rubocop-minitest", actual)
    find_node '.send[receiver=nil][message=assert][arguments.size=1] [arguments.first=.send[message=!=]]' do
      group do
        replace :message, with: 'refute_equal'
        replace :arguments, with: '{{arguments.first.receiver}}, {{arguments.first.arguments}}'
      end
    end

    # assert(!"rubocop-minitest" == (actual))
    # =>
    # refute_equal("rubocop-minitest", actual)
    find_node '.send[receiver=nil][message=assert][arguments.size=1]
                    [arguments.first=.send[message===][receiver=.send[message=!]]]' do
      group do
        replace :message, with: 'refute_equal'
        replace :arguments, with: '{{arguments.first.receiver.receiver}}, {{arguments.first.arguments}}'
      end
    end
  end
end
