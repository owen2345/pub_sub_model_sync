# frozen_string_literal: true

module PubSubModelSync
  module SubscriberConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # @param settings (Hash): { as_klass: nil, actions: nil, id: nil }
      def ps_msync_subscribe(attrs, settings = {})
        settings[:as_klass] = (settings[:as_klass] || name).to_s
        actions = settings.delete(:actions) || %i[create update destroy]
        @ps_msync_subscriber_settings = { attrs: attrs }.merge(settings)
        actions.each do |action|
          add_ps_msync_subscriber(settings[:as_klass], action, action, false)
        end
      end

      def ps_msync_class_subscribe(action, as_action: nil, as_klass: nil)
        add_ps_msync_subscriber(as_klass, action, as_action, true)
      end

      def ps_msync_subscriber_settings
        @ps_msync_subscriber_settings || {}
      end

      private

      def add_ps_msync_subscriber(as_klass, action, as_action, direct_mode)
        listener = {
          klass: name,
          as_klass: (as_klass || name).to_s,
          action: action.to_sym,
          as_action: (as_action || action).to_sym,
          direct_mode: direct_mode
        }
        PubSubModelSync::Config.listeners << listener
      end
    end
  end
end
