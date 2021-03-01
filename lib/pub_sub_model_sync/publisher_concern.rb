# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:ps_init_transaction_callbacks)
    end

    # Before initializing sync service (callbacks: after create/update/destroy)
    def ps_skip_callback?(_action)
      false
    end

    # before preparing data to sync
    def ps_skip_sync?(_action)
      false
    end

    # before delivering data (return :cancel to cancel sync)
    def ps_before_sync(_action, _payload); end

    # after delivering data
    def ps_after_sync(_action, _payload); end

    # To perform sync on demand
    # @param action (Sym): Action name (can be actions configured with "ps_publish" or custom actions)
    #   To deliver custom actions (not configured with "ps_publish"), custom_data is mandatory.
    # @param custom_data (nil|Hash) If present custom_data will be used as the payload data. I.E.
    #   data generator will be ignored
    # @param custom_headers (Hash, optional): refer Payload.headers
    def ps_perform_sync(action = :create, custom_data: nil, custom_headers: {})
      publisher = self.class.ps_publisher(action).dup
      publisher.custom_data = custom_data if custom_data
      p_klass = PubSubModelSync::MessagePublisher
      p_klass.publish_model(self, action, publisher: publisher, custom_headers: custom_headers)
    end

    module ClassMethods
      # Permit to configure to publish crud actions (:create, :update, :destroy)
      # @param headers (Hash, optional): Refer Payload.headers
      def ps_publish(attrs, actions: %i[create update destroy], as_klass: nil, headers: {})
        klass = PubSubModelSync::Publisher
        publisher = klass.new(attrs, name, actions, as_klass, headers: headers)
        PubSubModelSync::Config.publishers << publisher
        actions.each do |action|
          ps_register_callback(action.to_sym, publisher)
        end
      end

      # Publisher info for specific action
      def ps_publisher(action = :create)
        PubSubModelSync::Config.publishers.find do |publisher|
          publisher.klass == name && publisher.actions.include?(action)
        end
      end

      private

      # TODO: skip all enqueued notifications after_rollback (when failed)
      # Initialize calls to start and end pub_sub transactions and deliver all them in the same order
      def ps_init_transaction_callbacks
        start_transaction = lambda do
          key = PubSubModelSync::Publisher.ordering_key_for(self)
          @ps_old_transaction_key = PubSubModelSync::MessagePublisher.init_transaction(key)
        end
        end_transaction = -> { PubSubModelSync::MessagePublisher.end_transaction(@ps_old_transaction_key) }
        after_create start_transaction, prepend: true # wait for ID
        before_update start_transaction, prepend: true
        before_destroy start_transaction, prepend: true
        after_commit end_transaction
        after_rollback end_transaction
      end

      # Configure specific callback and execute publisher when called callback
      def ps_register_callback(action, publisher)
        after_commit(on: action) do |model|
          disabled = PubSubModelSync::Config.disabled_callback_publisher.call(model, action)
          if !disabled && !model.ps_skip_callback?(action)
            klass = PubSubModelSync::MessagePublisher
            klass.publish_model(model, action.to_sym, publisher: publisher)
          end
        end
      end
    end
  end
end
