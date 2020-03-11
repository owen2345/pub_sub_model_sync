# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    def ps_msync_skip_for?(_action)
      false
    end

    module ClassMethods
      # @param settings (Hash): { actions: nil, as_class: nil, id: nil }
      def ps_msync_publish(attrs, settings = {})
        actions ||= %i[create update destroy]
        ps_msync_register_callbacks(actions)
        ps_msync_save_crud_settings(attrs, settings)
      end

      def ps_msync_publisher_settings
        @ps_msync_publisher_settings || {}
      end

      def ps_msync_class_publish(data, action:, as_class: nil)
        as_class = (as_class || name).to_s
        ps_msync_publisher.publish_data(as_class, data, action.to_s)
      end

      def ps_msync_publisher
        PubSubModelSync::Publisher.new
      end

      private

      def ps_msync_save_crud_settings(attrs, settings)
        settings[:as_class] = (settings[:as_class] || name).to_s
        @ps_msync_publisher_settings = settings.merge(attrs: attrs)
      end

      def ps_msync_register_callbacks(actions)
        actions.each do |action|
          after_commit(on: action) do |model|
            unless model.ps_msync_skip_for?(action)
              publisher = model.class.ps_msync_publisher
              puts "@@@@ publishereeer: #{publisher.inspect}"
              publisher.publish_model(model, action.to_s)
            end
          end
        end
      end

      def log(msg)
        config.log(msg)
      end
    end
  end
end
