# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Before initializing sync service (callbacks: after create/update/destroy)
    def ps_skip_callback?(_action)
      false
    end

    # before preparing data to sync
    def ps_skip_sync?(_action)
      false
    end

    # before delivering data
    def ps_before_sync(_action, _data); end

    # after delivering data
    def ps_after_sync(_action, _data); end

    # To perform sync on demand
    # @param attrs (Array, optional): custom attrs to be used
    # @param as_klass (Array, optional): custom klass name to be used
    # @param publisher (Publisher, optional): custom publisher object
    def ps_perform_sync(action = :create, attrs: nil, as_klass: nil,
                        publisher: nil)
      publisher ||= self.class.ps_publisher(action).dup
      publisher.attrs = attrs if attrs
      publisher.as_klass = as_klass if as_klass
      PubSubModelSync::MessagePublisher.publish_model(self, action, publisher)
    end

    module ClassMethods
      # Permit to configure to publish crud actions (:create, :update, :destroy)
      def ps_publish(attrs, actions: %i[create update destroy], as_klass: nil)
        klass = PubSubModelSync::Publisher
        publisher = klass.new(attrs, name, actions, as_klass)
        PubSubModelSync::Config.publishers << publisher
        actions.each do |action|
          ps_register_callback(action.to_sym, publisher)
        end
      end

      # On demand class level publisher
      def ps_class_publish(data, action:, as_klass: nil)
        as_klass = (as_klass || name).to_s
        klass = PubSubModelSync::MessagePublisher
        klass.publish_data(as_klass, data, action.to_sym)
      end

      # Publisher info for specific action
      def ps_publisher(action = :create)
        PubSubModelSync::Config.publishers.find do |publisher|
          publisher.klass == name && publisher.actions.include?(action)
        end
      end

      private

      def ps_register_callback(action, publisher)
        after_commit(on: action) do |model|
          unless model.ps_skip_callback?(action)
            klass = PubSubModelSync::MessagePublisher
            klass.publish_model(model, action.to_sym, publisher)
          end
        end
      end
    end
  end
end
