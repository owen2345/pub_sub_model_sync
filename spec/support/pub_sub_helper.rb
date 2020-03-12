# frozen_string_literal: true

module PubSubHelper
  def pub_sub_attrs_builder(klass, action, id = nil)
    PubSubModelSync::Publisher.build_attrs(klass, action, id)
  end
end

RSpec.configure do |config|
  config.include PubSubHelper
end
