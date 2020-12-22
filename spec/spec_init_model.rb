# frozen_string_literal: true

require 'active_record'
def prepare_database!
  root_path = File.dirname __dir__
  db = 'db/test.sqlite3'
  db_path = File.join(root_path, db)
  File.delete(db_path) if File.exist?(db_path)

  # ActiveRecord::Base.colorize_logging = false
  ActiveRecord::Base.logger = Logger.new(STDERR)
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
end

prepare_database!

class PublisherUser < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[id name email])
  def custom_id
    99
  end
end

class SubscriberUser < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[name])
  ps_class_subscribe(:greeting)
  ps_class_subscribe(:greeting, from_action: :greeting2)
  ps_class_subscribe(:greeting, from_action: :greeting3, from_klass: 'User')

  def self.greeting(args)
    puts args
  end

  # ****** testing usage
  def self.create_class_method(method_name, &block)
    self.class.send(:define_method, method_name) { |*_args| }
    block&.call
    self.class.send(:remove_method, method_name)
  end
  # ****** end testing usage
end

# custom crud listeners
class PublisherUser2 < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[id name custom_name], actions: %i[update], as_klass: 'User')

  def custom_id
    99
  end

  def custom_name
    'custom_name'
  end

  def ps_skip_callback?(_action)
    false
  end
end

class SubscriberUser2 < ActiveRecord::Base
  self.table_name = 'subscriber_users'
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[name], actions: %i[update], from_klass: 'User', id: :id)
  attr_accessor :custom_name
end
