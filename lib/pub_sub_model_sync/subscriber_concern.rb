# frozen_string_literal: true

module PubSubModelSync
  module SubscriberConcern
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:attr_accessor, :ps_processed_payload)
    end

    # permit to apply custom actions before applying sync
    # @return (nil|:cancel): nil to continue sync OR :cancel to skip sync
    def ps_before_save_sync(_payload); end

    module ClassMethods
      def ps_subscribe(attrs, actions: nil, from_klass: name, id: :id)
        settings = { id: id, from_klass: from_klass }
        actions ||= %i[create update destroy]
        actions.each do |action|
          add_ps_subscriber(action, attrs, settings)
        end
      end

      def ps_class_subscribe(action, from_action: nil, from_klass: nil)
        settings = { direct_mode: true }
        settings[:from_action] = from_action if from_action
        settings[:from_klass] = from_klass if from_klass
        add_ps_subscriber(action, nil, settings)
      end

      def ps_subscriber(action = :create)
        PubSubModelSync::Config.subscribers.find do |subscriber|
          subscriber.klass == name && subscriber.action == action
        end
      end

      private

      # @param settings (Hash): refer to PubSubModelSync::Subscriber.settings
      def add_ps_subscriber(action, attrs, settings = {})
        klass = PubSubModelSync::Subscriber
        subscriber = klass.new(name, action, attrs: attrs, settings: settings)
        PubSubModelSync::Config.subscribers.push(subscriber) && subscriber
      end
    end
  end
end
