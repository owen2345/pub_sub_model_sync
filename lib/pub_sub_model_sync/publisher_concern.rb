# frozen_string_literal: true

module PubSubModelSync
  module PublisherConcern
    extend ActiveSupport::Concern

    included do
      extend ClassMethods
      ps_init_transaction_callbacks if self <= ActiveRecord::Base
    end

    # before delivering data (return :cancel to cancel sync)
    def ps_before_publish(_action, _payload); end
    alias ps_before_sync ps_before_publish # @deprecated

    # after delivering data
    def ps_after_publish(_action, _payload); end
    alias ps_after_sync ps_after_publish # @deprecated

    # Delivers a notification via pubsub
    # @param action (Sym|String) Sample: create|update|save|destroy|<any_other_key>
    # @param mapping? (Array<String>) If present will generate data using the mapping and added to the payload.
    #   Sample: ["id", "full_name:name"]
    # @param data? (Hash|Symbol|Proc)
    #   Hash: Data to be added to the payload
    #   Symbol: Method name to be called to retrieve payload data (must return a hash value, receives :action name)
    #   Proc: Block to be called to retrieve payload data
    # @param headers? (Hash|Symbol|Proc): (All available attributes in Payload.headers)
    #   Hash: Data that will be merged with default header values
    #   Symbol: Method name that will be called to retrieve header values (must return a hash, receives :action name)
    #   Proc: Block to be called to retrieve header values
    # @param as_klass? (String): Output class name used instead of current class name
    def ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: self.class.name)
      p_klass = PubSubModelSync::MessagePublisher
      p_klass.publish_model(self, action, data: data, mapping: mapping, headers: headers, as_klass: as_klass)
    end
    delegate :ps_class_publish, to: :class

    # Permits to perform manually the callback for a specific action
    # @param action (Symbol, default: :create) Only :create|:update|:destroy
    def ps_perform_publish(action = :create)
      items = self.class.ps_cache_publish_callbacks.select { |item| item[:actions].include?(action) }
      raise(StandardError, "No callback found for action :#{action}") if items.empty?

      items.each { |item| instance_exec(action, &item[:callback]) }
    end

    module ClassMethods
      # Publishes a class level notification via pubsub
      # @param data (Hash): Data of the notification
      # @param action (Symbol): action  name of the notification
      # @param as_klass (String, default current class name): Class name of the notification
      # @param headers (Hash, optional): header settings (More in Payload.headers)
      def ps_class_publish(data, action:, as_klass: nil, headers: {})
        klass = PubSubModelSync::MessagePublisher
        klass.publish_data((as_klass || name).to_s, data, action.to_sym, headers: headers)
      end

      # @param crud_actions (Symbol|Array<Symbol>): :create, :update, :destroy
      # @param method_name (Symbol, optional) method to be called
      def ps_after_action(crud_actions, method_name = nil, &block)
        actions = Array(crud_actions).map(&:to_sym)
        callback = ->(action) { method_name ? send(method_name, action) : instance_exec(action, &block) }
        ps_cache_publish_callbacks({ actions: actions, callback: callback })
        actions.each do |action|
          if action == :destroy
            after_destroy { instance_exec(action, &callback) }
          else
            ps_define_commit_action(action, callback)
          end
        end
      end

      def ps_cache_publish_callbacks(new_value = nil)
        @ps_cache_publish_callbacks ||= []
        @ps_cache_publish_callbacks << new_value if new_value
        @ps_cache_publish_callbacks
      end

      private

      def ps_define_commit_action(action, callback)
        if PubSubModelSync::Config.enable_rails4_before_commit # rails 4 compatibility
          define_method("ps_before_#{action}_commit") { instance_exec(action, &callback) }
        else
          commit_name = respond_to?(:before_commit) ? :before_commit : :after_commit
          send(commit_name, on: action) { instance_exec(action, &callback) }
        end
      end

      # Initialize calls to start and end pub_sub transactions and deliver all them in the same order
      def ps_init_transaction_callbacks
        start_transaction = lambda do
          @ps_transaction = PubSubModelSync::MessagePublisher.init_transaction(nil)
        end
        before_create start_transaction, prepend: true
        before_update start_transaction, prepend: true
        before_destroy start_transaction, prepend: true
        after_commit { @ps_transaction&.finish }
        after_rollback(prepend: true) { @ps_transaction&.rollback }
      end
    end
  end
end
