# frozen_string_literal: true

module PubSubHelper
  def pub_sub_attrs_builder(klass, action, id = nil)
    {
      class: klass.to_s,
      action: action.to_s,
      id: id,
      service_model_sync: true
    }
  end
end

RSpec.configure do |config|
  config.include PubSubHelper
end
