# frozen_string_literal: true

Synvert::Rewriter.new 'ruby', 'nested_class_definition' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    It converts compact class definition to nested class definition.

    ```ruby
    class Foo::Bar < Base
      def test; end
    end
    ```

    =>

    ```ruby
    module Foo
      class Bar < Base
        def test; end
      end
    end
    ```
  EOS

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # class Foo::Bar < Base
    #   def test; end
    # end
    # =>
    # module Foo
    #   class Bar < Base
    #     def test; end
    #   end
    # end
    find_node '.class[name=~/::/]' do
      source = node.to_source
      parts = node.name.to_source.split('::')
      class_name = parts.pop
      new_parts = parts.map.with_index { |mod, index| (' ' * NodeMutation.tab_width * index) + "module #{mod}" }
      new_parts.concat(source.sub(parts.join('::') + '::', '').split("\n").map { |line| (' ' * NodeMutation.tab_width * parts.size) + line })
      new_parts.concat(parts.map.with_index { |mod, index| (' ' * NodeMutation.tab_width * (parts.size - index - 1)) + "end" })

      replace_with new_parts.join("\n")
    end
  end
end
