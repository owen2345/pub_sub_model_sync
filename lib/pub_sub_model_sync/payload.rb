# frozen_string_literal: true

module PubSubModelSync
  class Payload
    attr_reader :data, :attributes, :headers

    # @param data (Hash: { any value }):
    # @param attributes (Hash: { klass: string, action: :sym }):
    def initialize(data, attributes, headers = {})
      @data = data
      @attributes = attributes
      @headers = headers
      build_headers
    end

    def to_h
      { data: data, attributes: attributes, headers: headers }
    end

    def klass
      attributes[:klass]
    end

    def action
      attributes[:action]
    end

    private

    def build_headers
      headers[:uuid] ||= SecureRandom.uuid
      headers[:app_key] ||= PubSubModelSync::Config.subscription_key
    end
  end
end
