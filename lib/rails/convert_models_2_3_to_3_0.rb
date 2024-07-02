# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_models_2_3_to_3_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails models from 2.3 to 3.0.

    ```ruby
    named_scope :active, :conditions => {:active => true}, :order => "created_at desc"
    named_scope :my_active, lambda { |user| {:conditions => ["user_id = ? and active = ?", user.id, true], :order => "created_at desc"} }
    ```

    =>

    ```ruby
    scope :active, where(:active => true).order("created_at desc")
    scope :my_active, lambda { |user| where("user_id = ? and active = ?", user.id, true).order("created_at desc") }
    ```

    ```ruby
    default_scope :order => "id DESC"
    ```

    =>

    ```ruby
    default_scope order("id DESC")
    ```

    ```ruby
    Post.find(:all, :limit => 2)
    Post.find(:all)
    Post.find(:first)
    Post.find(:last, :conditions => {:title => "test"})
    Post.first(:conditions => {:title => "test"})
    Post.all(:joins => :comments)
    ```

    =>

    ```ruby
    Post.limit(2)
    Post.all
    Post.first
    Post.where(:title => "test").last
    Post.where(:title => "test").first
    Post.joins(:comments)
    ```

    ```ruby
    Post.find_in_batches(:conditions => {:title => "test"}, :batch_size => 100) do |posts|
    end
    Post.find_in_batches(:conditions => {:title => "test"}) do |posts|
    end
    ```

    =>

    ```ruby
    Post.where(:title => "test").find_each(:batch_size => 100) do |post|
    end
    Post.where(:title => "test").find_each do |post|
    end
    ```

    ```ruby
    with_scope(:find => {:conditions => {:active => true}}) { Post.first }
    with_exclusive_scope(:find => {:limit =>1}) { Post.last }
    ```

    =>

    ```ruby
    with_scope(where(:active => true)) { Post.first }
    with_exclusive_scope(limit(1)) { Post.last }
    ```

    ```ruby
    Client.count("age", :conditions => {:active => true})
    Client.average("orders_count", :conditions => {:active => true})
    Client.min("age", :conditions => {:active => true})
    Client.max("age", :conditions => {:active => true})
    Client.sum("orders_count", :conditions => {:active => true})
    ```

    =>

    ```ruby
    Client.where(:active => true).count("age")
    Client.where(:active => true).average("orders_count")
    Client.where(:active => true).min("age")
    Client.where(:active => true).max("age")
    Client.where(:active => true).sum("orders_count")
    ```

    ```ruby
    self.errors.on(:email).present?
    ```

    =>

    ```ruby
    self.errors[:email].present?
    ```

    ```ruby
    self.errors.add_to_base("error message")
    ```

    =>

    ```ruby
    self.errors.add(:base, "error message")
    ```

    ```ruby
    self.save(false)
    ```

    =>

    ```ruby
    self.save(:validate => false)
    ```

    ```ruby
    Post.update_all({:title => "title"}, {:title => "test"})
    Post.update_all("title = \'title\'", "title = \'test\'")
    Post.update_all("title = \'title\'", ["title = ?", title])
    Post.update_all({:title => "title"}, {:title => "test"}, {:limit => 2})
    ```

    =>

    ```ruby
    Post.where(:title => "test").update_all(:title => "title")
    Post.where("title = \'test\'").update_all("title = \'title\'")
    Post.where(["title = ?", title]).update_all("title = \'title\'")
    Post.where(:title => "test").limit(2).update_all(:title => "title")
    ```

    ```ruby
    Post.delete_all("title = \'test\'")
    Post.delete_all(["title = ?", title])
    ```

    =>

    ```ruby
    Post.where("title = \'test\'").delete_all
    Post.where(["title = ?", title]).delete_all
    ```

    ```ruby
    Post.destroy_all("title = \'test\'")
    Post.destroy_all(["title = ?", title])
    ```

    =>

    ```ruby
    Post.where("title = \'test\'").destroy_all
    Post.where(["title = ?", title]).destroy_all
    ```
  EOS

  if_gem 'activerecord', '>= 3.0'

  keys = %i[conditions order joins select from having group include limit offset lock readonly]
  keys_converters = { conditions: :where, include: :includes }

  helper_method :generate_new_queries do |hash_node|
    new_queries = []
    hash_node.elements.each do |element_node|
      if keys.include?(element_node.key.to_value)
        method = keys_converters[element_node.key.to_value] || element_node.key.to_value
        new_queries << "#{method}(#{strip_brackets(element_node.value.to_source)})"
      end
    end
    new_queries.join('.')
  end

  helper_method :generate_batch_options do |hash_node|
    options = []
    hash_node.elements.each do |element_node|
      if %i[start batch_size].include?(element_node.key.to_value)
        options << element_node.to_source
      end
    end
    options.join(', ')
  end

  within_files Synvert::RAILS_APP_FILES + Synvert::RAILS_LIB_FILES do
    # named_scope :active, :conditions => {:active => true}
    # =>
    # named_scope :active, where(:active => true)
    #
    # default_scope :conditions => {:active => true}
    # =>
    # default_scope where(:active => true)
    within_node node_type: 'call_node',
                name: { in: ['named_scope', 'default_scope'] },
                arguments: { node_type: 'arguments_node', arguments: { last: { node_type: 'keyword_hash_node' } } } do
      goto_node 'arguments.arguments.-1' do
        if keys & node.keys.map(&:to_value)
          replace_with generate_new_queries(node)
        end
      end
    end

    # named_scope :active, lambda { {:conditions => {:active => true}} }
    # =>
    # named_scope :active, lambda { where(:active => true) }
    #
    # default_scope :active, lambda { {:conditions => {:active => true}} }
    # =>
    # default_scope :active, lambda { where(:active => true) }
    within_node node_type: 'call_node',
                name: { in: ['named_scope', 'default_scope'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    last: {
                      node_type: 'call_node',
                      block: { node_type: 'block_node', body: { body: { first: { node_type: 'hash_node' } } } }
                    }
                  }
                } do
      goto_node 'arguments.arguments.-1.block.body.body.0' do
        if keys & node.keys.map(&:to_value)
          replace_with generate_new_queries(node)
        end
      end
    end

    # named_scope :active, where(:active => true)
    # =>
    # scope :active, where(:active => true)
    with_node node_type: 'call_node', name: 'named_scope' do
      replace :message, with: 'scope'
    end

    # scoped(:conditions => {:active => true})
    # =>
    # where(:active => true)
    within_node node_type: 'call_node',
                name: 'scoped',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 1, first: { node_type: 'keyword_hash_node' } }
                } do
      if keys & node.arguments.arguments.first.keys.map(&:to_value)
        replace :message, :closing, with: generate_new_queries(node.arguments.arguments.first)
      end
    end

    # Post.all(:joins => :comments)
    # =>
    # Post.joins(:comments).all
    within_node node_type: 'call_node',
                name: 'all',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 1, first: { node_type: 'keyword_hash_node' } }
                } do
      if keys & node.arguments.arguments.first.keys.map(&:to_value)
        replace :message, :closing, with: "#{generate_new_queries(node.arguments.arguments.first)}"
      end
    end

    # Post.first(:conditions => {:title => "test"})
    # =>
    # Post.where(:title => "test").first
    within_node node_type: 'call_node',
                name: { in: ['first', 'last'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 1, first: { node_type: 'keyword_hash_node' } }
                } do
      if keys & node.arguments.arguments.first.keys.map(&:to_value)
        replace :message, :closing, with: "#{generate_new_queries(node.arguments.arguments.first)}.{{name}}"
      end
    end

    # Client.count("age", :conditions => {:active => true})
    # Client.average("orders_count", :conditions => {:active => true})
    # Client.min("age", :conditions => {:active => true})
    # Client.max("age", :conditions => {:active => true})
    # Client.sum("orders_count", :conditions => {:active => true})
    # =>
    # Client.where(:active => true).count("age")
    # Client.where(:active => true).average("orders_count")
    # Client.where(:active => true).min("age")
    # Client.where(:active => true).max("age")
    # Client.where(:active => true).sum("orders_count")
    within_node node_type: 'call_node',
                name: { in: %w[count average min max sum] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 2, last: { node_type: 'keyword_hash_node' } }
                } do
      if keys & node.arguments.arguments.last.keys.map(&:to_value)
        group do
          insert ".#{generate_new_queries(node.arguments.arguments.last)}", to: 'receiver', at: 'end'
          delete 'arguments.arguments.-1', and_comma: true
        end
      end
    end

    # Post.find(:all, :limit => 2)
    # =>
    # Post.limit(2)
    with_node node_type: 'call_node',
              name: 'find',
              arguments: {
                node_type: 'arguments_node',
                arguments: { size: 2, first: :all, last: { node_type: 'keyword_hash_node' } }
              } do
      if keys & node.arguments.arguments.last.keys.map(&:to_value)
        replace :message, :closing, with: generate_new_queries(node.arguments.arguments.last)
      end
    end

    # Post.find(:all)
    # =>
    # Post.all
    with_node node_type: 'call_node',
              name: 'find',
              arguments: { node_type: 'arguments_node', arguments: { size: 1, first: :all } } do
      group do
        replace :message, with: 'all'
        delete :opening, :closing
      end
    end

    # Post.find(:last, :conditions => {:title => "test"})
    # =>
    # Post.where(:title => "title").last
    within_node node_type: 'call_node',
                name: 'find',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    size: 2,
                    first: { in: [:first, :last] },
                    last: { node_type: 'keyword_hash_node' }
                  }
                } do
      if keys & node.arguments.arguments.last.keys.map(&:to_value)
        replace :message,
                :closing,
                with: "#{generate_new_queries(node.arguments.arguments.last)}.{{arguments.arguments.first.to_value}}"
      end
    end

    # Post.find(:first)
    # =>
    # Post.first
    within_node node_type: 'call_node',
                name: 'find',
                arguments: { node_type: 'arguments_node', arguments: { size: 1, first: { in: [:first, :last] } } } do
      replace :message, :closing, with: "{{arguments.arguments.first.to_value}}"
    end

    # Post.update_all({:title => "title"}, {:title => "test"})
    # Post.update_all("title = \'title\'", "title = \'test\'")
    # Post.update_all("title = \'title\'", ["title = ?", title])
    # =>
    # Post.where(:title => "test").update_all(:title => "title")
    # Post.where("title = \'test\'").update_all("title = \'title\'")
    # Post.where("title = ?", title).update_all("title = \'title\'")
    within_node node_type: 'call_node',
                name: :update_all,
                arguments: { node_type: 'arguments_node', arguments: { size: 2 } } do
      group do
        insert '.where({{arguments.arguments.first}})', to: 'receiver', at: 'end'
        delete 'arguments.arguments.first', and_comma: true
      end
    end

    # Post.update_all({:title => "title"}, {:title => "test"}, {:limit => 2})
    # =>
    # Post.where(:title => "test").limit(2).update_all(:title => "title")
    within_node node_type: 'call_node',
                name: :update_all,
                arguments: { node_type: 'arguments_node', arguments: { size: 3 } } do
      group do
        insert '.where({{arguments.arguments.first}})', to: 'receiver', at: 'end'
        insert ".#{generate_new_queries(node.arguments.arguments.last)}", to: 'receiver', at: 'end'
        delete 'arguments.arguments.0', and_comma: true
        delete 'arguments.arguments.-1', and_comma: true
      end
    end

    # Post.delete_all("title = \'test\'")
    # Post.delete_all(["title = ?", title])
    # =>
    # Post.where("title = \'test\'").delete_all
    # Post.where("title = ?", title).delete_all
    #
    # Post.destroy_all("title = \'test\'")
    # Post.destroy_all(["title = ?", title])
    # =>
    # Post.where("title = \'test\'").destroy_all
    # Post.where("title = ?", title).destroy_all
    within_node node_type: 'call_node',
                name: { in: ['delete_all', 'destroy_all'] },
                arguments: { node_type: 'arguments_node', arguments: { size: 1 } } do
      group do
        replace :message, with: 'where'
        insert ".{{message}}"
      end
    end

    # Post.find_each(:conditions => {:title => "test"}, :batch_size => 100) do |post|
    # end
    # =>
    # Post.where(:title => "test").find_each(:batch_size => 100) do |post|
    # end
    #
    # Post.find_in_batches(:conditions => {:title => "test"}, :batch_size => 100) do |posts|
    # end
    # =>
    # Post.where(:title => "test").find_in_batches(:batch_size => 100) do |posts|
    # end
    within_node node_type: 'call_node',
                name: { in: ['find_each', 'find_in_batches'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 1, first: { node_type: 'keyword_hash_node' } }
                } do
      argument_node = node.arguments.arguments.first
      if keys & argument_node.keys.map(&:to_value)
        batch_options = generate_batch_options(argument_node)
        if batch_options.length > 0
          replace :message, :closing, with: "#{generate_new_queries(argument_node)}.{{message}}(#{batch_options})"
        else
          replace :message, :closing, with: "#{generate_new_queries(argument_node)}.{{message}}"
        end
      end
    end

    # with_scope(:find => {:conditions => {:active => true}}) { Post.first }
    # =>
    # with_scope(where(:active => true)) { Post.first }
    #
    # with_exclusive_scope(:find => {:limit =>1}) { Post.last }
    # =>
    # with_exclusive_scope(limit(1)) { Post.last }
    within_node node_type: 'call_node',
                name: { in: ['with_scope', 'with_exclusive_scope'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    size: 1,
                    first: { node_type: 'keyword_hash_node', find_value: { not: nil } }
                  }
                } do
      replace :arguments, with: generate_new_queries(node.arguments.arguments.first.find_value.to_value)
    end
  end

  within_files Synvert::RAILS_APP_FILES + Synvert::RAILS_LIB_FILES + Synvert::RAILS_TEST_FILES do
    # self.errors.on(:email).present?
    # =>
    # self.errors[:email].present?
    with_node node_type: 'call_node', name: 'on', receiver: /errors$/ do
      group do
        replace :call_operator, :opening, with: '['
        replace :closing, with: ']'
      end
    end

    # self.errors.add_to_base("error message")
    # =>
    # self.errors.add(:base, "error message")
    with_node node_type: 'call_node', name: 'add_to_base', receiver: { node_type: 'call_node', name: 'errors' } do
      group do
        replace :message, with: 'add'
        insert ':base', to: 'arguments', at: 'beginning', and_comma: true
      end
    end

    # self.save(false)
    # =>
    # self.save(:validate => false)
    with_node node_type: 'call_node', name: 'save', arguments: { node_type: 'arguments_node', arguments: [false] } do
      replace :arguments, with: ':validate => false'
    end
  end
end
