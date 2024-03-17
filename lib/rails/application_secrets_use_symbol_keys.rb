# frozen_string_literal: true

Synvert::Rewriter.new 'rails', 'application_secrets_use_symbol_keys' do
  configure(parser: Synvert::PARSER_PARSER)

  description <<~EOS
    If your application stores nested configuration in `config/secrets.yml`, all keys are now loaded as symbols, so access using strings should be changed.

    From:

    ```ruby
    Rails.application.secrets[:smtp_settings]["address"]
    ```

    To:

    ```ruby
    Rails.application.secrets[:smtp_settings][:address]
    ```
  EOS

  if_gem 'rails', '>= 5.1'

  within_files Synvert::ALL_RUBY_FILES + Synvert::ALL_RAKE_FILES do
    # Rails.appplication.config.secrets[:smtp_settings]["address"]
    # =>
    # Rails.appplication.config.secrets[:smtp_settings][:address]
    with_node node_type: 'send',
              receiver: /^Rails.application.config.secrets/,
              message: '[]',
              arguments: { first: { node_type: 'str' } } do
      replace 'arguments.first', with: '{{arguments.first.to_symbol}}'
    end
  end
end
