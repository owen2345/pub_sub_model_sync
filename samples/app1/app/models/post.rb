# == Schema Information
#
# Table name: posts
#
#  id          :integer          not null, primary key
#  title       :string
#  description :text
#  user_id     :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Post < ApplicationRecord
  belongs_to :user

  include PubSubModelSync::PublisherConcern
  ps_after_action(%i[create update destroy]) do |action|
    ps_publish(action, mapping: %i[id title description user_id])
  end
end
