# frozen_string_literal: true

module PubSubModelSync
  class Subscriber < PubSubModelSync::Base
    attr_accessor :klass, :action, :mapping, :settings, :from_klass
    attr_reader :payload, :model

    # @param klass (String) class name
    # @param action (Symbol) @refer SubscriberConcern.ps_subscribe
    # @param mapping (Array<String>) @refer SubscriberConcern.ps_subscribe
    # @param settings (Hash): @refer SubscriberConcern.ps_subscribe
    def initialize(klass, action, mapping: [], settings: {})
      def_settings = { from_klass: klass, to_action: action, id: :id, if: nil, unless: nil, mode: :klass }
      @klass = klass
      @mapping = mapping
      @settings = def_settings.merge(settings)
      @action = action.to_sym
      @from_klass = @settings[:from_klass].to_s
    end
  end
end
