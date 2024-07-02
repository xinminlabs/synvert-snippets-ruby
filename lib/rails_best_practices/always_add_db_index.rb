# frozen_string_literal: true

Synvert::Rewriter.new 'rails_best_practices', 'always_add_db_index' do
  description <<~EOS
    Review db/schema.rb file to make sure every reference key has a database index.

    See the best practice details here https://rails-bestpractices.com/posts/2010/07/24/always-add-db-index/
  EOS

  call_helper 'rails/parse'
  rails_tables = load_data :rails_tables
  rails_models = load_data :rails_models

  configure(parser: Synvert::PRISM_PARSER)

  helper_method :foreign_key_column do |association|
    association[:foreign_key]&.to_s || association[:name].foreign_key
  end

  helper_method :foreign_type_column do |association|
    association[:foreign_type]&.to_s || (association[:name].demodulize + '_type').underscore
  end

  within_files 'db/schema.rb' do
    rails_tables.each do |table_name, table_info|
      belongs_to_associations =
        rails_models[:associations].select do |association|
          # find all belongs_to associations
          association[:class_name].tableize == table_name && association[:type] == 'belongs_to'
        end
      polymorphic_belongs_to_associations =
        belongs_to_associations.select do |association|
          next false unless association[:polymorphic]

          # find all belongs_to associations without db index
          table_info[:columns].find { |column| column[:name] == foreign_key_column(association) } &&
            table_info[:columns].find { |column| column[:name] == foreign_type_column(association) } &&
            !table_info[:indices].find { |index|
              index[:columns].first == foreign_type_column(association) && index[:columns].second == foreign_key_column(association)
            }
        end
      general_belongs_to_associations =
        belongs_to_associations.select do |association|
          !association[:polymorphic] &&
            # find all belongs_to associations without db index
            table_info[:columns].find { |column| column[:name] == foreign_key_column(association) } &&
            !table_info[:indices].find { |index| index[:columns].first == foreign_key_column(association) }
        end

      polymorphic_belongs_to_associations.each do |association|
        find_node ".call_node[receiver=nil][name=create_table][arguments!=nil][arguments.arguments.first='#{table_name}']
                   .call_node[receiver=t][arguments!=nil][arguments.arguments.first='#{association[:name].foreign_key}']" do
          warn "always add db index #{table_name} => [\"#{foreign_type_column(association)}\", \"#{foreign_key_column(association)}\"]"
        end
      end

      general_belongs_to_associations.each do |association|
        find_node ".call_node[receiver=nil][name=create_table][arguments!=nil][arguments.arguments.first='#{table_name}']
                   .call_node[receiver=t][arguments!=nil][arguments.arguments.first='#{foreign_key_column(association)}']" do
          warn "always add db index #{table_name} => [\"#{foreign_key_column(association)}\"]"
        end
      end
    end
  end
end
