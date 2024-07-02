# frozen_string_literal: true

Synvert::Rewriter.new 'ruby', 'prefer-endless-method' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It prefers endless method.

    ```ruby
    def one_plus_one
      1 + 1
    end
    ```

    =>

    ```ruby
    def one_plus_one = 1 + 1
    ```
  EOS

  if_ruby '3.0'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    find_node '.def_node[body!=nil][body.body.length=1]' do
      body_column = mutation_adapter.get_start_loc(node.body.body.first).column
      new_body = node.body.body.first.to_source.split("\n").map { |line| line.sub(/^ {#{body_column}}/, '') }
                     .join("\n")
      replace_with "def {{name}}{{lparen}}{{parameters}}{{rparen}} = #{new_body}"
    end
  end
end
