# frozen_string_literal: true

Synvert::Rewriter.new 'rspec', 'one_liner_expectation' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It convers rspec one liner expectation.

    ```ruby
    it { should matcher }
    it { should_not matcher }

    it { should have(3).items }

    it { should have_at_least(3).players }
    ```

    =>

    ```ruby
    it { is_expected.to matcher }
    it { is_expected.not_to matcher }

    it 'has 3 items' do
      expect(subject.size).to eq(3)
    end

    it 'has at least 3 players' do
      expect(subject.players.size).to be >= 3
    end
    ```
  EOS

  if_gem 'rspec-core', '>= 2.99'

  matcher_converters = { have: 'eq', have_exactly: 'eq', have_at_least: 'be >=', have_at_most: 'be <=' }
  within_files Synvert::RAILS_RSPEC_FILES do
    { should: 'to', should_not: 'not_to' }.each do |old_message, new_message|
      # it { should matcher } => it { is_expected.to matcher }
      # it { should_not matcher } => it { is_expected.not_to matcher }
      with_node node_type: 'block',
                caller: { message: 'it' },
                body: { size: 1, first: { node_type: 'send', receiver: nil, message: old_message } } do
        receiver = node.body.first.arguments.first.receiver
        unless receiver && matcher_converters.include?(receiver.message)
          matcher = node.body.first.arguments.first.to_source
          replace_with "it { is_expected.#{new_message} #{matcher} }"
        end
      end

      # it { should have(3).items }
      # =>
      # it 'has 3 items' do
      #   expect(subject.size).to eq(3)
      # end
      #
      # it { should have_at_least(3).players }
      # =>
      # it 'has at least 3 players' do
      #   expect(subject.players.size).to be >= 3
      # end
      matcher_converters.each do |old_matcher, new_matcher|
        with_node node_type: 'block',
                  caller: { message: 'it' },
                  body: {
                    size: 1,
                    first: {
                      node_type: 'send',
                      receiver: nil,
                      message: old_message,
                      arguments: {
                        first: {
                          node_type: 'send',
                          receiver: {
                            node_type: 'send',
                            message: old_matcher
                          }
                        }
                      }
                    }
                  } do
          times = node.body.first.arguments.first.receiver.arguments.first.to_source
          items_name = node.body.first.arguments.first.message
          if :items == items_name
            replace_with <<~EOS
              it 'has #{times} items' do
                expect(subject.size).#{new_message} #{new_matcher}(#{times})
              end
            EOS
          else
            replace_with <<~EOS
              it '#{old_matcher.to_s.sub('have', 'has').tr('_', ' ')} #{times} #{items_name}' do
                expect(subject.#{items_name}.size).#{new_message} #{new_matcher} #{times}
              end
            EOS
          end
        end
      end
    end
  end
end
