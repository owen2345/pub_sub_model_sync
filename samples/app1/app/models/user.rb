# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  name       :string
#  email      :string
#  age        :integer
#  address    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  accepts_nested_attributes_for :posts

  include PubSubModelSync::PublisherConcern
  ps_after_action(:create) do
    ps_publish(:create, mapping: %i[id name email age])
  end

  ps_after_action(:update) do
    ps_publish(:update, mapping: %i[id name email age])
  end

  ps_after_action(:destroy) do
    ps_publish(:destroy, mapping: %i[id])
  end
end
