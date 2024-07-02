# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ruby converts Kernel#open to URI.open' do
  context 'convert' do
    let(:rewriter_name) { 'ruby/kernel_open_to_uri_open' }
    let(:test_content) { "open('http://test.com')" }
    let(:test_rewritten_content) { "URI.open('http://test.com')" }

    include_examples 'convertable'
  end

  context 'not convert when define open method' do
    let(:rewriter_name) { 'ruby/kernel_open_to_uri_open' }
    let(:test_content) { <<~EOS }
      def open(url)
      end

      open('http://test.com')
    EOS
    let(:test_rewritten_content) { <<~EOS }
      def open(url)
      end

      open('http://test.com')
    EOS

    include_examples 'convertable'
  end
end
