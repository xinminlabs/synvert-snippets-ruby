# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_after_commit' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts active_record after_commit.

    ```ruby
    after_commit :add_to_index_later, on: :create
    after_commit :update_in_index_later, on: :update
    after_commit :remove_from_index_later, on: :destroy
    after_commit :add_to_index_later, on: [:create]
    after_commit :update_in_index_later, on: [:update]
    after_commit :save_to_index_later, on: [:create, :update]
    after_commit :remove_from_index_later, on: [:destroy]
    ```
    =>

    ```ruby
    after_create_commit :add_to_index_later
    after_update_commit :update_in_index_later
    after_detroy_commit :remove_from_index_later
    after_create_commit :add_to_index_later
    after_update_commit :update_in_index_later
    after_save_commit :save_to_index_later
    after_detroy_commit :remove_from_index_later
    ```
  EOS

  if_gem 'activerecord', '>= 5.0'

  within_files Synvert::RAILS_MODEL_FILES do
    # after_commit :add_to_index_later, on: :create
    # after_commit :update_in_index_later, on: :update
    # after_commit :remove_from_index_later, on: :destroy
    # =>
    # after_create_commit :add_to_index_later
    # after_update_commit :update_in_index_later
    # after_destroy_commit :remove_from_index_later
    with_node node_type: 'call_node',
              receiver: nil,
              name: 'after_commit',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  '1': { node_type: 'keyword_hash_node', on_value: { in: %i[create update destroy] } }
                }
              } do
      group do
        replace :name, with: 'after_{{arguments.arguments.-1.on_value.to_value}}_commit'
        delete 'arguments.arguments.-1.on_element', and_comma: true
      end
    end

    # after_commit :add_to_index_later, on: [:create]
    # after_commit :update_in_index_later, on: [:update]
    # after_commit :save_to_index_later, on: [:create, :update]
    # after_commit :remove_from_index_later, on: [:destroy]
    # =>
    # after_create_commit :add_to_index_later
    # after_update_commit :update_in_index_later
    # after_save_commit :save_to_index_later
    # after_destroy_commit :remove_from_index_later
    with_node node_type: 'call_node',
              receiver: nil,
              message: 'after_commit',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  '1': { node_type: 'keyword_hash_node', on_value: { node_type: 'array_node' } }
                }
              } do
      group do
        if node.arguments.arguments[1].on_value.elements.size == 1
          replace :message, with: 'after_{{arguments.arguments.-1.on_value.elements.0.to_value}}_commit'
          delete 'arguments.arguments.-1.on_element', and_comma: true
        elsif node.arguments.arguments[1].on_value.elements.size == 2
          if (node.arguments.arguments[1].on_value.elements.map(&:to_value) & %i[create update]).size == 2
            replace :message, with: 'after_save_commit'
            delete 'arguments.arguments.-1.on_element', and_comma: true
          end
        end
      end
    end
  end
end
