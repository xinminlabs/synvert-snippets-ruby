# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_models_3_2_to_4_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails models from 3.2 to 4.0.

    1. it replaces instance method serialized_attributes with class method.

    ```ruby
    self.serialized_attributes
    ```

    =>

    ```ruby
    self.class.serialized_attributes
    ```

    2. it replaces `dependent: :restrict` to `dependent: :restrict_with_exception`.
  EOS

  if_gem 'activerecord', '>= 4.0'

  within_files Synvert::RAILS_MODEL_FILES do
    # self.serialized_attributes => self.class.serialized_attributes
    with_node node_type: 'call_node', receiver: 'self', name: 'serialized_attributes' do
      insert 'class.', to: 'message', at: 'beginning'
    end

    # has_many :comments, dependent: :restrict => has_many :comments, dependent: restrict_with_exception
    within_node node_type: 'call_node',
                receiver: nil,
                name: { in: ['has_one', 'has_many'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { last: { node_type: 'keyword_hash_node', dependent_value: :restrict } }
                } do
      replace 'arguments.arguments.-1.dependent_value', with: ':restrict_with_exception'
    end
  end
end
