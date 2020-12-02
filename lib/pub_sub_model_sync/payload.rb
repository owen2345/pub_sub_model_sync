# frozen_string_literal: true

module PubSubModelSync
  class Payload
    attr_reader :data, :attributes

    # @param data (Hash: { any value }):
    # @param attributes (Hash: { klass: string, action: :sym }):
    def initialize(data, attributes)
      @data = data
      @attributes = attributes
    end

    def to_h
      { data: data, attributes: attributes }
    end

    def klass
      attributes[:klass]
    end

    def action
      attributes[:action]
    end

    private

    def set_unique_id
      attributes[:uuid] ||= SecureRandom.uuid
    end
  end
end
