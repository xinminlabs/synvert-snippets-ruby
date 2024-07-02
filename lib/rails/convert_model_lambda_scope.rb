# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_model_lambda_scope' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts activerecord scope to lambda scope.

    ```ruby
    class Post < ActiveRecord::Base
      scope :active, where(active: true)
      scope :published, Proc.new { where(published: true) }
      scope :by_user, proc { |user_id| where(user_id: user_id) }
      default_scope order("updated_at DESC")
      default_scope { order("created_at DESC") }
    end
    ```

    =>

    ```ruby
    class Post < ActiveRecord::Base
      scope :active, -> { where(active: true) }
      scope :published, -> { where(published: true) }
      scope :by_user, ->(user_id) { where(user_id: user_id) }
      default_scope -> { order("updated_at DESC") }
      default_scope -> { order("created_at DESC") }
    end
    ```
  EOS

  if_gem 'activerecord', '>= 4.0'

  within_files Synvert::RAILS_MODEL_FILES do
    # scope :active, where(active: true) => scope :active, -> { where(active: true) }
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'scope',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  last: {
                    node_type: 'call_node',
                    name: { not_in: ['new', 'proc', 'lambda'] }
                  }
                }
              } do
      goto_node 'arguments.arguments.last' do
        wrap prefix: '-> { ', suffix: ' }'
      end
    end

    with_node node_type: 'call_node',
              receiver: nil,
              name: 'scope',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  last: {
                    node_type: 'call_node',
                    receiver: 'Proc',
                    name: 'new'
                  }
                }
              } do
      if node.arguments.arguments.last.block.parameters
        replace 'arguments.arguments.last',
                with: '->({{arguments.arguments.last.block.parameters.parameters}}) { {{arguments.arguments.last.block.body}} }'
      else
        replace 'arguments.arguments.last', with: '-> { {{arguments.arguments.last.block.body}} }'
      end
    end

    with_node node_type: 'call_node',
              receiver: nil,
              name: 'scope',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  last: {
                    node_type: 'call_node',
                    receiver: nil,
                    name: { in: ['proc', 'lambda'] }
                  }
                }
              } do
      if node.arguments.arguments.last.block.parameters
        replace 'arguments.arguments.last',
                with: '->({{arguments.arguments.last.block.parameters.parameters}}) { {{arguments.arguments.last.block.body}} }'
      else
        replace 'arguments.arguments.last', with: '-> { {{arguments.arguments.last.block.body}} }'
      end
    end

    # default_scope order("updated_at DESC") => default_scope -> { order("updated_at DESC") }
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'default_scope',
              arguments: { node_type: 'arguments_node', arguments: { size: 1, first: { node_type: 'call_node' } } } do
      replace_with 'default_scope -> { {{arguments.arguments.first}} }'
    end

    # default_scope { order("updated_at DESC") } => default_scope -> { order("updated_at DESC") }
    with_node node_type: 'call_node', receiver: nil, name: 'default_scope', block: { node_type: 'block_node' } do
      replace_with 'default_scope -> { {{block.body.body}} }'
    end
  end
end
