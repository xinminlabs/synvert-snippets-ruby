# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'use_active_storage_image_processing_macros' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It uses active_storage image processing macros.

    ```ruby
    video.preview(resize: "100x100")
    video.preview(resize: "100x100>")
    video.preview(resize: "100x100^")
    ```

    =>

    ```ruby
    video.preview(resize_to_fit: [100, 100])
    video.preview(resize_to_limit: [100, 100])
    video.preview(resize_to_fill: [100, 100])
    ```
  EOS

  if_gem 'activestorage', '>= 6.1'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    with_node node_type: 'call_node',
              name: 'preview',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 1,
                  first: { node_type: 'keyword_hash_node', resize_value: { not: nil } }
                }
              } do
      resize_value = node.arguments.arguments.first.resize_value.to_value
      width, height = resize_value.split('x')
      if resize_value.ends_with?('>')
        replace 'arguments.arguments.first.resize_element', with: "resize_to_limit: [#{width.to_i}, #{height.to_i}]"
      elsif resize_value.ends_with?('^')
        replace 'arguments.arguments.first.resize_element', with: "resize_to_fill: [#{width.to_i}, #{height.to_i}]"
      else
        replace 'arguments.arguments.first.resize_element', with: "resize_to_fit: [#{width.to_i}, #{height.to_i}]"
      end
    end
  end
end
