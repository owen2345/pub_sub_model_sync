# frozen_string_literal: true

module PubSubModelSync
  module SubscriberConcern
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:attr_accessor, :ps_processing_payload)
      base.send(:cattr_accessor, :ps_processing_payload)
    end

    module ClassMethods
      # @param actions (Symbol,Array<Symbol>) Notification.action name: save|create|update|destroy|<any_other_action>
      # @param mapping (Array<String,Symbol>) Attributes mapping with aliasing support, sample: ["id", "full_name:name"]
      # @param settings (Hash<:from_klass, :to_action, :id, :if, :unless>)
      #   from_klass (String) Notification.class name
      #   to_action (Symbol,Proc):
      #     Symbol: Method to process the notification
      #     Proc: Block to process the notification
      #   id (Symbol,Array<Symbol,String>) attribute(s) DB primary identifier(s). Supports for mapping format.
      #   if (Symbol,Proc,Array<Symbol>) Method or block called as the conformation before calling the callback
      #   unless (Symbol,Proc,Array<Symbol>) Method or block called as the negation before calling the callback
      def ps_subscribe(actions, mapping = [], settings = {}, &block)
        settings[:to_action] ||= block if block
        Array(actions).map do |action|
          add_ps_subscriber(action, mapping, settings)
        end
      end

      # @param action (Symbol) Notification.action name
      # @param settings (Hash) @refer ps_subscribe.settings except(:id)
      def ps_class_subscribe(action, settings = {}, &block)
        settings[:to_action] ||= block if block
        add_ps_subscriber(action, nil, settings.merge(mode: :klass))
      end

      private

      # @param settings (Hash): refer to PubSubModelSync::Subscriber.settings
      def add_ps_subscriber(action, mapping, settings = {})
        klass = PubSubModelSync::Subscriber
        subscriber = klass.new(name, action, mapping: mapping, settings: settings)
        PubSubModelSync::Config.subscribers.push(subscriber) && subscriber
      end
    end
  end
end
