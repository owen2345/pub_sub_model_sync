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

def migrate!
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
end

class Post < ActiveRecord::Base
  belongs_to :publisher_user
  include PubSubModelSync::PublisherConcern
  after_save_commit { ps_publish(:save, mapping: %i[id title]) }
end

class SubscriberUser < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern

  def self.hello(*_args); end

  # ****** testing usage
  def self.create_class_method(method_name, &block)
    self.class.send(:define_method, method_name) { |*_args| }
    block&.call
    self.class.send(:remove_method, method_name)
  end
  # ****** end testing usage
end
