# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'update_active_storage_variant_argument' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It updates active_storage variant method argument.

    ```ruby
    image.variant(resize: "100x")
    image.variant(crop: "1920x1080+0+0")
    image.variant(resize_and_pad: [300, 300])
    image.variant(monochrome: true)
    ```

    =>

    ```ruby
    image.variant(resize_to_limit: [100, nil])
    image.variant(crop: [0, 0, 1920, 1080])
    image.variant(resize_and_pad: [300, 300, background: [255]])
    image.variant(colourspace: "b-w")
    ```
  EOS

  if_gem 'activestorage', '>= 7.0'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    with_node node_type: 'send',
              message: 'variant',
              arguments: {
                size: 1,
                first: { node_type: 'hash', resize_value: { node_type: 'str', value: { last: 'x' } } }
              } do
      width = node.arguments.first.resize_value.to_value.to_i
      replace 'arguments.first.resize_pair', with: "resize_to_limit: [#{width}, nil]"
    end

    with_node node_type: 'send',
              message: 'variant',
              arguments: { size: 1, first: { node_type: 'hash', crop_value: { node_type: 'str' } } } do
      width, height, x, y = node.arguments.first.crop_value.to_value.split(/x|\+/)
      replace :arguments, with: "crop: [#{x}, #{y}, #{width}, #{height}]"
    end

    with_node node_type: 'send',
              message: 'variant',
              arguments: {
                size: 1,
                first: {
                  node_type: 'hash',
                  resize_and_pad_value: { node_type: 'array', elements: { size: 2 } }
                }
              } do
      insert 'background: [255]', to: 'arguments.0.pairs.0.value.elements.-1', at: 'end', and_comma: true
    end

    with_node node_type: 'send',
              message: 'variant',
              arguments: { size: 1, first: { node_type: 'hash', monochrome_value: true } } do
      replace 'arguments.first.monochrome_pair', with: 'colourspace: "b-w"'
    end
  end
end
