# frozen_string_literal: true

module PubSubModelSync
  module SubscriberConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def ps_subscribe(attrs, actions: nil, as_klass: name, id: :id)
        settings = { id: id, as_klass: as_klass }
        actions ||= %i[create update destroy]
        actions.each do |action|
          add_ps_subscriber(action, attrs, settings)
        end
      end

      def ps_class_subscribe(action, as_action: nil, as_klass: nil)
        settings = { direct_mode: true }
        settings[:as_action] = as_action if as_action
        settings[:as_klass] = as_klass if as_klass
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
