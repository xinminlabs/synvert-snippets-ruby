# frozen_string_literal: true

require 'spec_helper'
require 'helpers/parse_rails'

RSpec.describe 'rails/parse helper', fakefs: true do
  it 'saves tables data' do
    rewriter =
      Synvert::Rewriter.new 'test', 'rails_parse_helper' do
        call_helper 'rails/parse'
      end

    file_path = 'db/schema.rb'
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, <<~EOF)
      ActiveRecord::Schema[7.1].define(version: 2024_04_22_081242) do
        # These are extensions that must be enabled in order to support this database
        enable_extension "plpgsql"

        create_table "users", force: :cascade do |t|
          t.string "name", null: false
          t.string "email", null: false
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
          t.index ["email"], name: "index_users_on_email", unique: true
        end
      end
    EOF

    rewriter.process

    expect(rewriter.load_data(:rails_tables)).to eq(
      {
        "users" => {
          columns: [
            { name: "name", type: "string" },
            { name: "email", type: "string" },
            { name: "created_at", type: "datetime" },
            { name: "updated_at", type: "datetime" }
          ],
          indices: [
            { columns: ["email"], name: "index_users_on_email" }
          ]
        }
      }
    )
  end

  it 'saves associations' do
    rewriter =
      Synvert::Rewriter.new 'test', 'rails_parse_helper' do
        call_helper 'rails/parse'
      end

    FileUtils.mkdir_p('app/models')
    File.write('app/models/user.rb', <<~EOF)
      class User < ApplicationRecord
        belongs_to :organization
        has_many :posts, dependent: :destroy
      end
    EOF
    File.write('app/models/picture.rb', <<~EOF)
      class Picture < ApplicationRecord
        belongs_to :imageable, polymorphic: true
      end
    EOF

    rewriter.process

    expect(rewriter.load_data(:rails_models)[:associations]).to eq(
      [
        {
          class_name: "Picture",
          name: "imageable",
          type: "belongs_to",
          polymorphic: true
        },
        {
          class_name: "User",
          name: "organization",
          type: "belongs_to"
        },
        {
          class_name: "User",
          name: "posts",
          type: "has_many"
        }
      ]
    )
  end
end
