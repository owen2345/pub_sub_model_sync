# == Schema Information
#
# Table name: customers
#
#  id         :integer          not null, primary key
#  full_name  :string
#  email      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Customer < ApplicationRecord
  include PubSubModelSync::SubscriberConcern

  has_many :posts

  ps_subscribe(%i[create update destroy], %i[name:full_name email], id: :id, from_klass: 'User')
  ps_subscribe(:send_email, [], from_klass: 'User') # instance subscription
  ps_class_subscribe(:send_emails, from_klass: 'User') # class subscription

  after_create { log "User created: #{inspect}" }
  after_update { log "User updated: #{inspect}" }
  after_destroy { log "User Destroyed: #{inspect}" }

  def self.send_emails(data)
    log("Sending emails to many users: #{data.inspect}")
  end

  def send_email(data)
    log("Sending email to: #{data.inspect}")
  end
end
