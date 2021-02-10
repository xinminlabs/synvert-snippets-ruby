# frozen_string_literal: true

Synvert::Rewriter.new 'rspec', 'its_to_it' do
  description <<-EOF
It converts rspec its to it.

    describe 'example' do
      subject { { foo: 1, bar: 2 } }
      its(:size) { should == 2 }
      its([:foo]) { should == 1 }
      its('keys.first') { should == :foo }
    end
    =>
    describe 'example' do
      subject { { foo: 1, bar: 2 } }

      describe '#size' do
        subject { super().size }
        it { should == 2 }
      end

      describe '[:foo]' do
        subject { super()[:foo] }
        it { should == 1 }
      end

      describe '#keys' do
        subject { super().keys }
        describe '#first' do
          subject { super().first }
          it { should == :foo }
        end
      end
    end
  EOF

  if_gem 'rspec', { gte: '2.99.0' }

  within_files 'spec/**/*.rb' do
    # describe 'example' do
    #   subject { { foo: 1, bar: 2 } }
    #   its(:size) { should == 2 }
    #   its([:foo]) { should == 1 }
    #   its('keys.first') { should == :foo }
    # end
    # =>
    # describe 'example' do
    #   subject { { foo: 1, bar: 2 } }
    #
    #   describe '#size' do
    #     subject { super().size }
    #     it { should == 2 }
    #   end
    #
    #   describe '[:foo]' do
    #     subject { super()[:foo] }
    #     it { should == 1 }
    #   end
    #
    #   describe '#keys' do
    #     subject { super().keys }
    #     describe '#first' do
    #       subject { super().first }
    #       it { should == :foo }
    #     end
    #   end
    # end
    [:should, :should_not].each do |_message|
      with_node type: 'block', caller: { message: 'its' } do
        if node.body.length == 1
          its_arg = node.caller.arguments.first.to_source
          its_arg = its_arg[1...-1] if its_arg =~ /^['"].*['"]$/
          its_arg = its_arg[1..-1] if its_arg[0] == ':'
          rewritten_code = []
          args = its_arg.split('.')
          args.each_with_index do |arg, index|
            describe_name = arg[0] =~ /^[a-z]/ ? '#' + arg : arg
            message_name = arg[0] =~ /^[a-z]/ ? '.' + arg : arg
            rewritten_code << "#{'  ' * index}describe '#{describe_name}' do"
            rewritten_code << "#{'  ' * (index + 1)}subject { super()#{message_name} }"
            rewritten_code << "#{'  ' * (index + 1)}it { {{body}} }" if index + 1 == args.length
          end
          args.length.times do |i|
            rewritten_code << "#{'  ' * (args.length - 1 - i)}end"
          end
          replace_with rewritten_code.join("\n")
        end
      end
    end
  end
end
