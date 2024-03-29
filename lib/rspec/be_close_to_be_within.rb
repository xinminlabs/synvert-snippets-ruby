# frozen_string_literal: true

Synvert::Rewriter.new 'rspec', 'be_close_to_be_within' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It converts rspec be_close matcher to be_within matcher.

    ```ruby
    expect(1.0 / 3.0).to be_close(0.333, 0.001)
    ```

    =>

    ```ruby
    expect(1.0 / 3.0).to be_within(0.001).of(0.333)
    ```
  EOS

  if_gem 'rspec-core', '>= 2.1'

  within_files Synvert::RAILS_RSPEC_FILES do
    # expect(1.0 / 3.0).to be_close(0.333, 0.001) => expect(1.0 / 3.0).to be_within(0.001).of(0.333)
    with_node node_type: 'send', message: 'to', arguments: { first: { node_type: 'send', message: 'be_close' } } do
      replace :arguments, with: "be_within({{arguments.first.arguments.last}}).of({{arguments.first.arguments.first}})"
    end
  end
end
