# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'convert_mailers_2_3_to_3_0' do
  configure(parser: Synvert::PRISM_PARSER)

  description <<~EOS
    It converts rails mailers from 2.3 to 3.0.

    ```ruby
    class Notifier < ActionMailer::Base
      def signup_notification(recipient)
        recipients      recipient.email_address_with_name
        subject         "New account information"
        from            "system@example.com"
        sent_on         Time.now
        content_type    "multipart/alternative"
        body            :account => recipient
      end
    end
    ```

    =>

    ```ruby
    class Notifier < ActionMailer::Base
      def signup_notification(recipient)
        @account = recipient
        mail(:to => recipient.email_address_with_name, :subject => "New account information", :from => "system@example.com", :date => Time.now)
      end
    end
    ```

    ```ruby
    Notifier.deliver_signup_notification(recipient)
    ```

    =>

    ```ruby
    Notifier.signup_notification(recipient).deliver
    ```

    ```ruby
    message = Notifier.create_signup_notification(recipient)
    Notifier.deliver(message)
    ```

    =>

    ```ruby
    message = Notifier.signup_notification(recipient)
    message.deliver
    ```
  EOS

  if_gem 'rails', '>= 3.0'

  mailer_methods = {}

  within_files Synvert::RAILS_MAILER_FILES + Synvert::RAILS_MODEL_FILES do
    # class Notifier < ActionMailer::Base
    #   def signup_notification(recipient)
    #     recipients      recipient.email_address_with_name
    #     subject         "New account information"
    #     from            "system@example.com"
    #     sent_on         Time.now
    #     content_type    "multipart/alternative"
    #     body            :account => recipient
    #   end
    # end
    # =>
    # class Notifier < ActionMailer::Base
    #   def signup_notification(recipient)
    #     @account = recipient
    #     mail(:to => recipient.email_address_with_name, :subject => "New account information", :from => "system@example.com", :date => Time.now)
    #   end
    # end
    within_node node_type: 'class_node', superclass: 'ActionMailer::Base' do
      class_name = node.name
      within_node node_type: 'def_node' do
        args = {}
        with_node node_type: 'call_node',
                  receiver: nil,
                  name: 'recipients',
                  arguments: { node_type: 'arguments_node', arguments: { size: 1 } } do
          args[:to] = node.arguments.arguments.first.to_source
          remove
        end
        with_node node_type: 'call_node', receiver: nil, name: { in: %w[subject from cc bcc] } do
          args[node.name] = node.arguments.arguments.first.to_source
          remove
        end
        with_node node_type: 'call_node', receiver: nil, name: 'sent_on' do
          args[:date] = node.arguments.arguments.first.to_source
          remove
        end
        with_node node_type: 'call_node', receiver: nil, name: 'content_type' do
          remove
        end
        with_node node_type: 'call_node',
                  receiver: nil,
                  name: 'body',
                  arguments: {
                    node_type: 'arguments_node',
                    arguments: { size: 1, first: { node_type: 'keyword_hash_node' } }
                  } do
          replace_with node.arguments.arguments.first.elements.map { |element|
                         "@#{element.key.to_value} = #{element.value.to_source}"
                       }
.join("\n")
        end
        if args.size > 0
          mailer_methods[class_name] ||= []
          mailer_methods[class_name] << node.name
          args_str = args.map { |key, value| ":#{key} => #{value}" }
                         .join(', ')
          append "mail(#{args_str})"
        end
      end
    end
  end

  within_files Synvert::RAILS_APP_FILES + Synvert::RAILS_LIB_FILES do
    # Notifier.deliver_signup_notification(recipient)
    # =>
    # Notifier.signup_notification(recipient).deliver
    with_node node_type: 'call_node', receiver: { not: nil }, name: /^deliver_/ do
      mailer_method = node.name.to_s.sub(/^deliver_/, '').to_sym
      if mailer_methods[node.receiver.name] && mailer_methods[node.receiver.name].include?(mailer_method)
        replace_with "{{receiver}}.#{mailer_method}({{arguments}}).deliver"
      end
    end

    # message = Notifier.create_signup_notification(recipient)
    # =>
    # message = Notifier.signup_notification(recipient)
    with_node node_type: 'call_node', receiver: { not: nil }, name: /^create_/ do
      mailer_method = node.name.to_s.sub(/^create_/, '').to_sym
      if mailer_methods[node.receiver.name] && mailer_methods[node.receiver.name].include?(mailer_method)
        replace_with "{{receiver}}.#{mailer_method}({{arguments}})"
      end
    end

    # Notifier.deliver(message)
    # =>
    # message.deliver
    with_node node_type: 'call_node',
              receiver: { not: nil },
              name: 'deliver',
              arguments: { node_type: 'arguments_node', arguments: { size: 1 } } do
      if mailer_methods[node.receiver.name]
        replace_with '{{arguments}}.{{message}}'
      end
    end
  end
end
