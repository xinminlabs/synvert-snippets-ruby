# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_routes_2_3_to_3_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails routes from 2.3 to 3.0.

    ```ruby
    map.root :controller => "home", :action => :index
    ```

    =>

    ```ruby
    root :to => "home#index"
    ```

    ```ruby
    map.connect "/:controller/:action/:id"
    ```

    =>

    ```ruby
    match "/:controller(/:action(/:id))(.:format)"
    ```

    ```ruby
    map.admin_signup "/admin_signup", :controller => "admin_signup", :action => "new", :method => "post"
    ```

    =>

    ```ruby
    post "/admin_signup", :to => "admin_signup#new", :as => "admin_signup"
    ```

    ```ruby
    map.with_options :controller => "manage" do |manage|
      manage.manage_index "manage_index", :action => "index"
      manage.manage_intro "manage_intro", :action => "intro"
    end
    ```

    =>

    ```ruby
    manage.manage_index "manage_index", :to => "index#manage"
    manage.manage_intro "manage_intro", :to => "intro#manage"
    ```

    ```ruby
    map.namespace :admin do |admin|
      admin.resources :users
    end
    ```

    =>

    ```ruby
    namespace :admin do
      resources :users
    end
    ```

    ```ruby
    map.resources :posts, :collection => { :generate_pdf => :get }, :member => {:activate => :post} do |posts|
      posts.resources :comments
    end
    ```

    =>

    ```ruby
    resources :posts do
      collection do
        get :generate_pdf
      end
      member do
        post :activate
      end
      resources :comments
    end
    ```
  EOS

  if_gem 'rails', '>= 3.0'

  helper_method :extract_controller_action_name do |hash_node|
    controller_name = hash_node.controller_value.to_value
    action_name = hash_node.action_value&.to_value || 'index'
    "#{controller_name}##{action_name}"
  end

  helper_method :extract_subdomain_node do |hash_node|
    if hash_node.keys.map(&:to_value).include?(:conditions) && hash_node.conditions_value.keys.map(&:to_value).include?(:subdomain)
      hash_node.conditions_value.subdomain_value
    end
  end

  helper_method :extract_method do |hash_node|
    method = hash_node.method_value.to_value if hash_node.keys.map(&:to_value).include?(:method)
    if !method && hash_node.keys.map(&:to_value).include?(:conditions) && hash_node.conditions_value.keys.map(&:to_value).include?(:method)
      method = hash_node.conditions_value.method_value.to_value
    end
    method || 'match'
  end

  helper_method :generate_new_member_routes do |member_routes|
    new_member_routes = []
    new_member_routes << "  member do\n"
    if [:hash_node, :keyword_hash_node].include?(member_routes.type)
      member_routes.elements.each do |element_node|
        Array(element_node.value.to_value).each do |method|
          method = 'match' if method == :any
          new_member_routes << "    #{method} :#{element_node.key.to_value}\n"
        end
      end
    else
      Array(member_routes.to_value).each do |method|
        new_member_routes << "    match :#{method}\n"
      end
    end
    new_member_routes << "  end\n"
    new_member_routes.join
  end

  helper_method :generate_new_collection_routes do |collection_routes|
    new_collection_routes = []
    new_collection_routes << "  collection do\n"
    if [:hash_node, :keyword_hash_node].include?(collection_routes.type)
      collection_routes.elements.each do |element_node|
        Array(element_node.value.to_value).each do |method|
          method = 'match' if method == :any
          new_collection_routes << "    #{method} :#{element_node.key.to_value}\n"
        end
      end
    else
      Array(collection_routes.to_value).each do |method|
        new_collection_routes << "    match :#{method}\n"
      end
    end
    new_collection_routes << "  end\n"
    new_collection_routes.join
  end

  helper_method :generate_new_child_routes do |block_node|
    block_node.body.body.map { |child_node|
      "  #{child_node.to_source.sub("#{block_node.parameters.parameters.requireds.first.to_source}.", '')}\n"
    }
.join('')
  end

  helper_method :reject_keys_from_hash do |hash_node, *keys|
    hash_node.elements.reject { |element_node| keys.include?(element_node.key.to_value) }
             .map(&:to_source).join(', ')
  end

  within_files Synvert::RAILS_ROUTE_FILES do
    # map.namespace :admin do |admin|
    #   admin.resources :users
    # end
    # =>
    # namespace :admin do
    #   resources :users
    # end
    with_node node_type: 'call_node',
              receiver: { not: nil },
              name: 'namespace',
              block: { node_type: 'block_node' },
              arguments: { not: nil } do
      new_routes = []
      new_routes << "namespace {{arguments}} do\n"
      new_routes << generate_new_child_routes(node.block)
      new_routes << 'end'
      replace_with new_routes.join
    end

    # map.with_options :controller => "manage" do |manage|
    #   manage.manage_index "manage_index", :action => "index"
    #   manage.manage_intro "manage_intro", :action => "intro"
    # end
    # =>
    # manage.manage_index "manage_index", :action => "index", :controller => "manage"
    # manage.manage_intro "manage_intro", :action => "intro", :controller => "manage"
    with_node node_type: 'call_node', name: 'with_options', block: { node_type: 'block_node' } do
      new_routes = []
      node.block.body.body.each do |child_node|
        next if child_node.arguments.nil?

        url = child_node.arguments.arguments.first.to_value
        hash_node = child_node.arguments.arguments.last
        if hash_node.action_value || url !~ /:action/
          controller_action_name = "#{node.arguments.arguments.first.controller_value.to_value}##{hash_node.action_value&.to_value || 'index'}"
          method = extract_method(hash_node)
          subdomain_node = extract_subdomain_node(hash_node)
          other_options_code = reject_keys_from_hash(hash_node, :controller, :action, :method, :conditions)
          other_options_code += ":constraints => {:subdomain => #{subdomain_node.to_source}}" if subdomain_node
          if other_options_code.length > 0
            new_routes << "#{method} #{child_node.arguments.arguments.first.to_source}, :to => #{wrap_with_quotes(controller_action_name)}, #{other_options_code}, :as => #{wrap_with_quotes(child_node.message.to_s)}"
          else
            new_routes << "#{method} #{child_node.arguments.arguments.first.to_source}, :to => #{wrap_with_quotes(controller_action_name)}, :as => #{wrap_with_quotes(child_node.message.to_s)}"
          end
        else
          new_routes << 'match {{arguments}}'
        end
      end
      replace_with new_routes.join("\n") + "\n"
    end

    # map.resources :posts, :collection => { :generate_pdf => :get }, :member => {:activate => :post} do |posts|
    #   posts.resources :comments
    # end
    # =>
    # resources :posts do
    #   collection do
    #     get :generate_pdf
    #   end
    #   member do
    #     post :activate
    #   end
    #   map.resources :comments
    # end
    within_node node_type: 'call_node',
                receiver: { not: nil },
                name: { in: ['resource', 'resources'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: { size: 2, last: { node_type: 'keyword_hash_node' } }
                } do
      hash_argument = node.arguments.arguments.last
      new_routes = []
      if !hash_argument.collection_value.nil? || !hash_argument.member_value.nil?
        collection_routes = hash_argument.collection_value
        member_routes = hash_argument.member_value
        other_options_code = reject_keys_from_hash(hash_argument, :collection, :member)
        if other_options_code.length > 0
          new_routes << "{{message}} {{arguments.arguments.first}}, #{other_options_code} do\n"
        else
          new_routes << "{{message}} {{arguments.arguments.first}} do\n"
        end
        new_routes << generate_new_collection_routes(collection_routes) if collection_routes
        new_routes << generate_new_member_routes(member_routes) if member_routes
      else
        new_routes << "{{message}} {{arguments}} do\n"
      end
      new_routes << generate_new_child_routes(node.block) if node.block
      new_routes << 'end'
      replace_with new_routes.join
    end

    # map.connect "/main/:id", :controller => "main", :action => "home"
    # => match "/main/:id", :to => "main#home"
    within_node node_type: 'call_node',
                receiver: 'map',
                name: 'connect',
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    last: {
                      node_type: 'keyword_hash_node',
                      action_value: { not: nil },
                      controller_value: { not: nil }
                    }
                  }
                } do
      hash_node = node.arguments.arguments.last
      controller_action_name = extract_controller_action_name(hash_node)
      method = hash_node.method_value ? hash_node.method_value.to_value : 'match'
      other_options_code = reject_keys_from_hash(hash_node, :controller, :action, :method)
      if other_options_code.length > 0
        replace_with "#{method} {{arguments.arguments.first}}, :to => #{wrap_with_quotes(controller_action_name)}, #{other_options_code}"
      else
        replace_with "#{method} {{arguments.arguments.first}}, :to => #{wrap_with_quotes(controller_action_name)}"
      end
    end

    # map.root :controller => "home", :action => :index
    # => root :to => "home#index"
    within_node node_type: 'call_node', receiver: 'map', name: 'root' do
      hash_node = node.arguments.arguments.last
      controller_action_name = extract_controller_action_name(hash_node)
      subdomain_node = extract_subdomain_node(hash_node)
      if subdomain_node
        replace_with "root :to => #{wrap_with_quotes(controller_action_name)}, :constraints => {:subdomain => #{subdomain_node.to_source}}"
      else
        replace_with "root :to => #{wrap_with_quotes(controller_action_name)}"
      end
    end

    # map.connect "/:controller/:action/:id"
    # => match "/:controller(/:action(/:id))(.:format)"
    with_node node_type: 'call_node',
              receiver: 'map',
              name: 'connect',
              arguments: { node_type: 'arguments_node', arguments: { first: %r|:controller/:action/:id| } } do
      replace_with 'match "/:controller(/:action(/:id))(.:format)"'
    end

    # map.connect "audio/:action/:id", :controller => "audio"
    # => match "audio(/:action(/:id))(.:format)", :controller => "audio"
    with_node node_type: 'call_node',
              receiver: 'map',
              name: 'connect',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  first: %r|(.*?)/:action/:id|,
                  last: { node_type: 'keyword_hash_node', controller_value: { not: nil } }
                }
              } do
      controller_name = node.arguments.arguments.last.controller_value.to_value
      replace_with "match #{wrap_with_quotes(controller_name + "(/:action(/:id))(.:format)")}, {{arguments.arguments.last}}"
    end

    # map.connect "video/:action", :controller => "video"
    # => match "video(/:action)(.:format)", :controller => "video"
    with_node node_type: 'call_node',
              receiver: 'map',
              name: 'connect',
              arguments: {
                node_type: 'arguments_node',
                arguments: {
                  size: 2,
                  first: %r|(.*?)/:action['"]$|,
                  last: { node_type: 'keyword_hash_node', controller_value: { not: nil } }
                }
              } do
      controller_name = node.arguments.arguments.last.controller_value.to_value
      replace_with "match #{wrap_with_quotes(controller_name + "(/:action)(.:format)")}, {{arguments.arguments.last}}"
    end

    # named routes
    # map.admin_signup "/admin_signup", :controller => "admin_signup", :action => "new", :method => "post"
    # => post "/admin_signup", :to => "admin_signup#new", :as => "admin_signup"
    within_node node_type: 'call_node',
                receiver: 'map',
                name: { not_in: ['root', 'connect', 'resource', 'resources'] },
                arguments: {
                  node_type: 'arguments_node',
                  arguments: {
                    size: 2,
                    last: { node_type: 'keyword_hash_node', controller_value: { not: nil } }
                  }
                } do
      url = node.arguments.arguments.first.to_value
      hash_node = node.arguments.arguments.last
      if hash_node.action_value || url !~ /:action/
        controller_action_name =
          if hash_node.action_value
            extract_controller_action_name(hash_node)
          else
            "#{hash_node.controller_value.to_value}#index"
          end
        method = extract_method(hash_node)
        subdomain_node = extract_subdomain_node(hash_node)
        other_options_code = reject_keys_from_hash(hash_node, :controller, :action, :method, :conditions)
        other_options_code += ":constraints => {:subdomain => #{subdomain_node.to_source}}" if subdomain_node
        if other_options_code.length > 0
          replace_with "#{method} {{arguments.arguments.first}}, :to => #{wrap_with_quotes(controller_action_name)}, #{other_options_code}, :as => #{wrap_with_quotes(node.message.to_s)}"
        else
          replace_with "#{method} {{arguments.arguments.first}}, :to => #{wrap_with_quotes(controller_action_name)}, :as => #{wrap_with_quotes(node.message.to_s)}"
        end
      else
        replace_with 'match {{arguments}}'
      end
    end
  end
end
