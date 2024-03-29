# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_after_commit' do
  configure(parser: Synvert::PARSER_PARSER)

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
    with_node node_type: 'send',
              receiver: nil,
              message: 'after_commit',
              arguments: {
                size: 2,
                '1': { node_type: 'hash', on_value: { in: %i[create update destroy] } }
              } do
      group do
        replace :message, with: 'after_{{arguments.-1.on_value.to_value}}_commit'
        delete 'arguments.-1.on_pair', and_comma: true
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
    with_node node_type: 'send',
              receiver: nil,
              message: 'after_commit',
              arguments: {
                size: 2,
                '1': { node_type: 'hash', on_value: { node_type: 'array' } }
              } do
      group do
        if node.arguments[1].on_value.elements.size == 1
          replace :message, with: 'after_{{arguments.-1.on_value.elements.0.to_value}}_commit'
          delete 'arguments.-1.on_pair', and_comma: true
        elsif node.arguments[1].on_value.elements.size == 2
          if (node.arguments[1].on_value.elements.map(&:to_value) & %i[create update]).size == 2
            replace :message, with: 'after_save_commit'
            delete 'arguments.-1.on_pair', and_comma: true
          end
        end
      end
    end
  end
end
