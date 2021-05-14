class Post < ApplicationRecord
  belongs_to :customer

  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[create update destroy], %i[title user_id:customer_id])

  after_create { log "Post created: #{inspect}" }
  after_update { log "Post updated: #{inspect}" }
  after_destroy { log "Post Destroyed: #{inspect}" }
end
