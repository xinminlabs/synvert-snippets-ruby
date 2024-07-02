# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Rails Best Practices always add db index' do
  before { load_helpers(%w[helpers/parse_rails]) }

  context 'index exists' do
    let(:rewriter_name) { 'rails_best_practices/always_add_db_index' }
    let(:file_paths) { %w[db/schema.rb app/models/comment.rb] }
    let(:test_contents) { [<<~EOF.strip, <<~EOF.strip] }
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        enable_extension "plpgsql"

        create_table "comments", force: :cascade do |t|
          t.string "content", null: false
          t.bigint "post_id", null: false
          t.integer "user_id", null: false
          t.index ["post_id"], name: "index_comments_on_post_id"
          t.index ["user_id"], name: "index_comments_on_user_id"
        end
      end
    EOF
      class Comment < ApplicationRecord
        belongs_to :post
        belongs_to :user
      end
    EOF
    let(:warnings) { [] }

    include_examples 'warnable'
  end

  context 'index is missing' do
    let(:rewriter_name) { 'rails_best_practices/always_add_db_index' }
    let(:file_paths) { %w[db/schema.rb app/models/comment.rb] }
    let(:test_contents) { [<<~EOF.strip, <<~EOF.strip] }
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        enable_extension "plpgsql"

        create_table "comments", force: :cascade do |t|
          t.string "content", null: false
          t.bigint "post_id", null: false
          t.integer "user_id", null: false
        end
      end
    EOF
      class Comment < ApplicationRecord
        belongs_to :post
        belongs_to :user
      end
    EOF
    let(:warnings) {
      [
        '/db/schema.rb#6: always add db index comments => ["post_id"]',
        '/db/schema.rb#7: always add db index comments => ["user_id"]'
      ]
    }

    include_examples 'warnable'
  end

  context 'polymorphic index exists' do
    let(:rewriter_name) { 'rails_best_practices/always_add_db_index' }
    let(:file_paths) { %w[db/schema.rb app/models/picture.rb] }
    let(:test_contents) { [<<~EOF.strip, <<~EOF.strip] }
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        enable_extension "plpgsql"

        create_table "pictures", force: :cascade do |t|
          t.string "name", null: false
          t.bigint "imageable_id", null: false
          t.string "imageable_type", null: false
          t.index ["imageable_type", "imageable_id"], name: "index_pictures_on_imageable_type_and_imageable_id"
        end
      end
    EOF
      class Picture < ApplicationRecord
        belongs_to :imageable, polymorphic: true
      end
    EOF
    let(:warnings) { [] }

    include_examples 'warnable'
  end

  context 'polymorphic index is missing' do
    let(:rewriter_name) { 'rails_best_practices/always_add_db_index' }
    let(:file_paths) { %w[db/schema.rb app/models/picture.rb] }
    let(:test_contents) { [<<~EOF.strip, <<~EOF.strip] }
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        enable_extension "plpgsql"

        create_table "pictures", force: :cascade do |t|
          t.string "name", null: false
          t.bigint "imageable_id", null: false
          t.string "imageable_type", null: false
        end
      end
    EOF
      class Picture < ApplicationRecord
        belongs_to :imageable, polymorphic: true
      end
    EOF
    let(:warnings) { ['/db/schema.rb#6: always add db index pictures => ["imageable_type", "imageable_id"]'] }

    include_examples 'warnable'
  end

  context 'foreign_key option index is missing' do
    let(:rewriter_name) { 'rails_best_practices/always_add_db_index' }
    let(:file_paths) { %w[db/schema.rb app/models/comment.rb] }
    let(:test_contents) { [<<~EOF.strip, <<~EOF.strip] }
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        enable_extension "plpgsql"

        create_table "comments", force: :cascade do |t|
          t.string "content", null: false
          t.integer "user_id", null: false
        end
      end
    EOF
      class Comment < ApplicationRecord
        belongs_to :commentor, foreign_key: :user_id
      end
    EOF
    let(:warnings) { ['/db/schema.rb#6: always add db index comments => ["user_id"]'] }

    include_examples 'warnable'
  end
end
