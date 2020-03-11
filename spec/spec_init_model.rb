# frozen_string_literal: true

require 'active_record'
def prepare_database!
  root_path = File.dirname __dir__
  db = 'db/test.sqlite3'
  ActiveRecord::Base.logger = Logger.new(STDERR)
  File.delete(File.join(root_path, db))
  # ActiveRecord::Base.colorize_logging = false
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
  ps_msync_publish(%i[name email])
  def custom_id
    99
  end
end

class SubscriberUser < ActiveRecord::Base
  include PubSubModelSync::Subscriber
  ps_msync_subscribe(%i[name])
  ps_msync_class_subscribe(:greeting)
  ps_msync_class_subscribe(:greeting2, as_action: :greeting)

  def self.greeting(args)
    puts args
  end

  def self.greeting2(args)
    puts args
  end
end

# custom crud listeners
class PublisherUser2 < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_msync_publish(%i[name], actions: %i[update], as_class: 'User', id: :custom_id)
  def custom_id
    99
  end
end

class SubscriberUser2 < ActiveRecord::Base
  self.table_name = 'subscriber_users'
  include PubSubModelSync::Subscriber
  ps_msync_subscribe(%i[name], actions: %i[update], as_class: 'User')
end
