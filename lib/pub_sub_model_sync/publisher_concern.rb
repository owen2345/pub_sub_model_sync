# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Permit to skip a publish callback
    def ps_msync_skip_for?(_action)
      false
    end

    module ClassMethods
      # Permit to publish crud actions (:create, :update, :destroy)
      # @param settings (Hash): { actions: nil, as_klass: nil, id: nil }
      def ps_msync_publish(attrs, settings = {})
        actions = settings.delete(:actions) || %i[create update destroy]
        @ps_msync_publisher_settings = settings.merge(attrs: attrs)
        ps_msync_register_callbacks(actions)
      end

      def ps_msync_publisher_settings
        @ps_msync_publisher_settings
      end

      def ps_msync_class_publish(data, action:, as_klass: nil)
        as_klass = (as_klass || name).to_s
        ps_msync_publisher.publish_data(as_klass, data, action.to_sym)
      end

      def ps_msync_publisher
        PubSubModelSync::Publisher.new
      end

      private

      def ps_msync_register_callbacks(actions)
        actions.each do |action|
          after_commit(on: action) do |model|
            unless model.ps_msync_skip_for?(action)
              publisher = model.class.ps_msync_publisher
              publisher.publish_model(model, action.to_sym)
            end
          end
        end
      end
    end
  end
end
