# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Convert rails configs from 4.0 to 4.1' do
  let(:rewriter_name) { 'rails/convert_configs_4_0_to_4_1' }
  let(:secret_token_content) { <<~EOS }
    Synvert::Application.config.secret_key_base = '47047aa27cf4549abec82ffd43abf47b114db8dab43bb482808a752cb10aae33af8df49f0a20c5876f707ef44fbec068c5607ddb47726565e7f7ec263bd3f799'
  EOS

  let(:secrets_yml_content) { <<~EOS }
    development:
      secret_key_base: f88a4878602b2294a6b82be380544a04ec7385cdb784e4f32ea5c7ba21bc225c5b2a71d9519368007f309da7e0c09a78101c74b906f705f488e51d4914f021c7

    test:
      secret_key_base: 91577fa95d46814424b75a8ea5a0af560644bc1fd38bdbd0f6d2a05acb143548cc3c0722c5e3362f3df9b72c2f88e8c66f6b60eacf609073b4c5b11af74e37f5

    # Do not keep production secrets in the repository,
    # instead read values from the environment.
    production:
      secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
  EOS

  let(:cookies_serializer_content) { 'Rails.application.config.action_dispatch.cookies_serializer = :json' }

  let(:fake_file_paths) {
    %w[
      config/secrets.yml
      config/initializers/secret_token.rb
      config/initializers/cookies_serializer.rb
    ]
  }
  let(:test_contents) { [nil, secret_token_content, nil] }
  let(:test_rewritten_contents) {
    [secrets_yml_content, nil, cookies_serializer_content]
  }

  before do
    expect(SecureRandom).to receive(:hex)
      .with(64)
      .and_return(
        'f88a4878602b2294a6b82be380544a04ec7385cdb784e4f32ea5c7ba21bc225c5b2a71d9519368007f309da7e0c09a78101c74b906f705f488e51d4914f021c7'
      )
    expect(SecureRandom).to receive(:hex)
      .with(64)
      .and_return(
        '91577fa95d46814424b75a8ea5a0af560644bc1fd38bdbd0f6d2a05acb143548cc3c0722c5e3362f3df9b72c2f88e8c66f6b60eacf609073b4c5b11af74e37f5'
      )
  end

  include_examples 'convertable with multiple files'
end
