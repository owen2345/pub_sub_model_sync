# frozen_string_literal: true

module PubSubModelSync
  module Subscriber
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def ps_msync_subscribe(attrs:, as_class: nil, actions: nil, id: nil)
        actions ||= %i[create update destroy]
        actions.each do |action|
          config = { attrs: attrs, direct_mode: nil, id: id }
          add_ps_msync_subscriber(as_class, action, action, config)
        end
      end

      def ps_msync_class_subscribe(action:, as_action: nil, as_class: nil)
        config = { direct_mode: true }
        add_ps_msync_subscriber(as_class, action, as_action, config)
      end

      private

      # @param config (Hash): { attrs: [], direct_mode: true/false, id: :id }
      def add_ps_msync_subscriber(as_class, action, as_action, config)
        listener = {
          class: name,
          as_class: as_class || name,
          action: action,
          as_action: as_action || action
        }.merge(config)
        PubSubModelSync::Config.listeners << listener
      end
    end
  end
end