# frozen_string_literal: true

module PubSubModelSync
  module SubscriberConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def ps_subscribe(attrs, as_klass: nil, actions: nil, id: :id)
        actions ||= %i[create update destroy]
        settings = { attrs: attrs, id: id }
        actions.each do |action|
          add_ps_subscriber(as_klass, action, action, false, settings)
        end
      end

      def ps_class_subscribe(action, as_action: nil, as_klass: nil)
        add_ps_subscriber(as_klass, action, as_action, true, {})
      end

      def ps_subscriber(action = :create)
        PubSubModelSync::Config.listeners.find do |listener|
          listener[:klass] == name && listener[:action] == action
        end
      end

      private

      # @param settings (Hash): { id:, attrs: }
      def add_ps_subscriber(as_klass, action, as_action, direct_mode, settings)
        listener = {
          klass: name,
          as_klass: (as_klass || name).to_s,
          action: action.to_sym,
          as_action: (as_action || action).to_sym,
          direct_mode: direct_mode,
          settings: settings
        }
        PubSubModelSync::Config.listeners.push(listener) && listener
      end
    end
  end
end
