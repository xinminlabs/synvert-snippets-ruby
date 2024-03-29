# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_models_2_3_to_3_0' do
  configure(parser: Synvert::PARSER_PARSER)

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
    hash_node.children.each do |pair_node|
      if keys.include? pair_node.key.to_value
        method = keys_converters[pair_node.key.to_value] || pair_node.key.to_value
        new_queries << "#{method}(#{strip_brackets(pair_node.value.to_source)})"
      end
    end
    new_queries.join('.')
  end

  helper_method :generate_batch_options do |hash_node|
    options = []
    hash_node.children.each do |pair_node|
      if %i[start batch_size].include? pair_node.key.to_value
        options << pair_node.to_source
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
    %w[named_scope default_scope].each do |message|
      within_node node_type: 'send', message: message, arguments: { last: { node_type: 'hash' } } do
        with_node node_type: 'hash' do
          if keys.any? { |key| node.key? key }
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
      within_node node_type: 'send', message: message, arguments: { last: { node_type: 'block' } } do
        within_node node_type: 'block' do
          with_node node_type: 'hash' do
            if keys.any? { |key| node.key? key }
              replace_with generate_new_queries(node)
            end
          end
        end
      end
    end

    # named_scope :active, where(:active => true)
    # =>
    # scope :active, where(:active => true)
    with_node node_type: 'send', message: 'named_scope' do
      replace :message, with: 'scope'
    end

    # scoped(:conditions => {:active => true})
    # =>
    # where(:active => true)
    within_node node_type: 'send', message: 'scoped' do
      if node.arguments.length == 1
        argument_node = node.arguments.first
        if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
          replace_with add_receiver_if_necessary(generate_new_queries(argument_node))
        end
      end
    end

    # Post.all(:joins => :comments)
    # =>
    # Post.joins(:comments).all
    within_node node_type: 'send', message: 'all', arguments: { size: 1 } do
      argument_node = node.arguments.first
      if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
        replace_with add_receiver_if_necessary(generate_new_queries(argument_node))
      end
    end

    %w[first last].each do |message|
      # Post.first(:conditions => {:title => "test"})
      # =>
      # Post.where(:title => "test").first
      within_node node_type: 'send', message: message, arguments: { size: 1 } do
        argument_node = node.arguments.first
        if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
          replace_with add_receiver_if_necessary("#{generate_new_queries(argument_node)}.#{message}")
        end
      end
    end

    %w[count average min max sum].each do |message|
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
      within_node node_type: 'send', message: message, arguments: { size: 2 } do
        argument_node = node.arguments.last
        if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
          replace_with add_receiver_if_necessary(
            "#{generate_new_queries(argument_node)}.#{message}({{arguments.first}})"
          )
        end
      end
    end

    # Post.find(:all, :limit => 2)
    # =>
    # Post.where(:limit => 2)
    with_node node_type: 'send', message: 'find', arguments: { size: 2, first: :all } do
      argument_node = node.arguments.last
      if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
        replace_with add_receiver_if_necessary(generate_new_queries(argument_node))
      end
    end

    # Post.find(:all)
    # =>
    # Post.all
    with_node node_type: 'send', message: 'find', arguments: { size: 1, first: :all } do
      replace_with add_receiver_if_necessary('all')
    end

    %i[first last].each do |message|
      # Post.find(:last, :conditions => {:title => "test"})
      # =>
      # Post.where(:title => "title").last
      within_node node_type: 'send', message: 'find', arguments: { size: 2, first: message } do
        argument_node = node.arguments.last
        if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
          replace_with add_receiver_if_necessary("#{generate_new_queries(argument_node)}.#{message}")
        end
      end

      # Post.find(:first)
      # =>
      # Post.first
      within_node node_type: 'send', message: 'find', arguments: { size: 1, first: message } do
        replace_with add_receiver_if_necessary(message)
      end
    end

    # Post.update_all({:title => "title"}, {:title => "test"})
    # Post.update_all("title = \'title\'", "title = \'test\'")
    # Post.update_all("title = \'title\'", ["title = ?", title])
    # =>
    # Post.where(:title => "test").update_all(:title => "title")
    # Post.where("title = \'test\'").update_all("title = \'title\'")
    # Post.where("title = ?", title).update_all("title = \'title\'")
    within_node node_type: 'send', message: :update_all, arguments: { size: 2 } do
      replace_with add_receiver_if_necessary("where({{arguments.first}}).update_all({{arguments.last}})")
    end

    # Post.update_all({:title => "title"}, {:title => "test"}, {:limit => 2})
    # =>
    # Post.where(:title => "test").limit(2).update_all(:title => "title")
    within_node node_type: 'send', message: :update_all, arguments: { size: 3 } do
      replace_with add_receiver_if_necessary("where({{arguments.first}}).#{generate_new_queries(node.arguments.last)}.update_all({{arguments.1}})")
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
    %w[delete_all destroy_all].each do |message|
      within_node node_type: 'send', message: message, arguments: { size: 1 } do
        replace :message, with: 'where'
        insert ".#{message}"
      end
    end

    %w[find_each find_in_batches].each do |message|
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
      within_node node_type: 'send', message: message, arguments: { size: 1 } do
        argument_node = node.arguments.first
        if :hash == argument_node.type && keys.any? { |key| argument_node.key? key }
          batch_options = generate_batch_options(argument_node)
          if batch_options.length > 0
            replace_with add_receiver_if_necessary(
              "#{generate_new_queries(argument_node)}.#{message}(#{batch_options})"
            )
          else
            replace_with add_receiver_if_necessary("#{generate_new_queries(argument_node)}.#{message}")
          end
        end
      end
    end

    %w[with_scope with_exclusive_scope].each do |message|
      # with_scope(:find => {:conditions => {:active => true}}) { Post.first }
      # =>
      # with_scope(where(:active => true)) { Post.first }
      #
      # with_exclusive_scope(:find => {:limit =>1}) { Post.last }
      # =>
      # with_exclusive_scope(limit(1)) { Post.last }
      within_node node_type: 'send', message: message, arguments: { size: 1 } do
        argument_node = node.arguments.first
        if :hash == argument_node.type && argument_node.key?(:find)
          replace_with "#{message}(#{generate_new_queries(argument_node.find_value.to_value)})"
        end
      end
    end
  end

  within_files Synvert::RAILS_APP_FILES + Synvert::RAILS_LIB_FILES + Synvert::RAILS_TEST_FILES do
    # self.errors.on(:email).present?
    # =>
    # self.errors[:email].present?
    with_node node_type: 'send', message: 'on', receiver: /errors$/ do
      replace_with '{{receiver}}[{{arguments}}]'
    end

    # self.errors.add_to_base("error message")
    # =>
    # self.errors.add(:base, "error message")
    with_node node_type: 'send', message: 'add_to_base', receiver: { node_type: 'send', message: 'errors' } do
      replace_with '{{receiver}}.add(:base, {{arguments}})'
    end

    # self.save(false)
    # =>
    # self.save(:validate => false)
    with_node node_type: 'send', message: 'save', arguments: [false] do
      replace :arguments, with: ':validate => false'
    end
  end
end
