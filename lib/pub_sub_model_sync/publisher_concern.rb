# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:ps_init_transaction_callbacks)
    end

    # before preparing data to sync
    def ps_skip_publish?(_action)
      false
    end
    alias ps_skip_sync? ps_skip_publish? # @deprecated

    # before delivering data (return :cancel to cancel sync)
    def ps_before_publish(_action, _payload); end
    alias ps_before_sync ps_before_publish # @deprecated

    # after delivering data
    def ps_after_publish(_action, _payload); end
    alias ps_after_sync ps_after_publish # @deprecated

    # To perform sync on demand
    # @param action (Sym|String) Sample: create|update|save|destroy|<any_other_key>
    # @param mapping? (Array<String>) If present will generate data using the mapping and added to the payload
    # @param data? (Hash|Symbol|Proc)
    #   Hash: Data to be added to the payload
    #   Symbol: Method name to be called to retrieve payload data (must return a hash value, receives :action name)
    #   Proc: Block to be called to retrieve payload data
    # @param headers? (Hash|Symbol|Proc): (All available attributes in Payload.headers)
    #   Hash: Data that will be merged with default header values
    #   Symbol: Method name that will be called to retrieve header values (must return a hash, receives :action name)
    #   Proc: Block to be called to retrieve header values
    def ps_publish_event(action, data: {}, mapping: [], headers: {})
      p_klass = PubSubModelSync::MessagePublisher
      p_klass.publish_model(self, action, data: data, mapping: mapping, headers: headers)
    end

    module ClassMethods
      # Klass level notification
      # @deprecated this method was deprecated in favor of:
      #   PubSubModelSync::MessagePublisher.publish_data(...)
      def ps_class_publish(data, action:, as_klass: nil, headers: {})
        klass = PubSubModelSync::MessagePublisher
        klass.publish_data((as_klass || name).to_s, data, action.to_sym, headers: headers)
      end

      private

      # TODO: skip all enqueued notifications after_rollback (when failed)
      # Initialize calls to start and end pub_sub transactions and deliver all them in the same order
      def ps_init_transaction_callbacks
        start_transaction = lambda do
          key = PubSubModelSync::Publisher.ordering_key_for(self)
          @ps_parent_transaction_key = PubSubModelSync::MessagePublisher.init_transaction(key)
        end
        end_transaction = -> { PubSubModelSync::MessagePublisher.end_transaction(@ps_parent_transaction_key) }
        after_create start_transaction, prepend: true # wait for ID
        before_update start_transaction, prepend: true
        before_destroy start_transaction, prepend: true
        after_commit end_transaction
        after_rollback end_transaction
      end
    end
  end
end
