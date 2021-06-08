# frozen_string_literal: true

require 'active_record'
def prepare_database!
  root_path = File.dirname __dir__
  db = 'db/test.sqlite3'
  db_path = File.join(root_path, db)
  File.delete(db_path) if File.exist?(db_path)

  # ActiveRecord::Base.colorize_logging = false
  ActiveRecord::Base.logger = Logger.new($stderr)
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: db
  )
  migrate!
end

def migrate! # rubocop:disable Metrics/MethodLength:
  ActiveRecord::Base.connection.create_table :publisher_users do |table|
    table.column :name, :string
    table.column :email, :string
    table.column :age, :integer
  end

  ActiveRecord::Base.connection.create_table :subscriber_users do |table|
    table.column :name, :string
    table.column :email, :string
    table.column :age, :integer
  end

  ActiveRecord::Base.connection.create_table :posts do |table|
    table.column :publisher_user_id, :integer
    table.column :title, :string
  end
end

prepare_database!

class PublisherUser < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  has_many :posts, dependent: :destroy
  accepts_nested_attributes_for :posts
end

class Post < ActiveRecord::Base
  belongs_to :publisher_user
  include PubSubModelSync::PublisherConcern
  ps_after_commit(%i[create update destroy]) { |action| ps_publish(action, mapping: %i[id title]) }
end

class SubscriberUser < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern

  def self.hello(*_args); end
end
