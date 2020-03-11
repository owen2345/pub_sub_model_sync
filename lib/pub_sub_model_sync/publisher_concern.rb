# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def ps_msync_publish(attrs:, actions: nil, as_class: nil, id: nil)
        actions ||= %i[create update destroy]
        ps_msync_register_callbacks(as_class, actions, attrs, id)
      end

      def ps_msync_class_publish(data, action:, as_class: nil)
        ps_msync_publisher.publish_data(as_class || name, data, action)
      end

      private

      def ps_msync_register_callbacks(as_class, actions, attrs, id)
        publisher = ps_msync_publisher
        actions.each do |action|
          after_commit(on: action) do |model|
            skip_sync = model.respond_to?(:ps_msync_skip_for?) &&
                        model.ps_msync_skip_for?(action)
            unless skip_sync
              publisher.publish_model(model, action, attrs, as_class, id)
            end
          end
        end
      end

      def ps_msync_publisher
        @ps_msync_publisher ||= PubSubModelSync::Publisher.new
      end

      def log(msg)
        config.log(msg)
      end
    end
  end
end