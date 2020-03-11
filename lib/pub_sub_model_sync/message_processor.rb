# frozen_string_literal: true

module PubSubModelSync
  class MessageProcessor
    attr_accessor :data, :attrs
    def initialize(data, attrs)
      @data = data
      @attrs = attrs
    end

    def process
      log 'processing message'
      listeners = filter_listeners
      eval_message(listeners) if listeners.any?
      log 'processed message'
    end

    private

    def eval_message(listeners)
      listeners.each do |listener|
        if listener[:direct_mode]
          call_class_listener(listener)
        else
          call_listener(listener)
        end
      end
    end

    def call_class_listener(listener)
      model_class = listener[:class].constantize
      model_class.send(listener[:action], data)
    rescue => e
      log("Error listener (#{listener}): #{e.message}", :error)
    end

    # support for: create, update, destroy
    def call_listener(listener)
      listener_add_crud_settings(listener)
      model = find_model(listener)
      if attrs[:action].to_s == 'destroy'
        model.destroy!
      else
        populate_model(model, listener)
        model.save!
      end
    rescue => e
      log("Error listener (#{listener}): #{e.message}", :error)
    end

    def find_model(listener)
      model_class = listener[:class].constantize
      identifier = listener[:settings][:id] || :id
      model_class.where(identifier => attrs[:id]).first || model_class.new
    end

    def populate_model(model, listener)
      values = data.slice(*listener[:settings][:attrs])
      values.each do |attr, value|
        model.send("#{attr}=", value)
      end
    end

    def filter_listeners
      listeners = PubSubModelSync::Config.listeners
      listeners.select do |listener|
        listener[:as_class].to_s == attrs[:class].to_s &&
          listener[:as_action].to_s == attrs[:action].to_s
      end
    end

    def listener_add_crud_settings(listener)
      model_class = listener[:class].constantize
      listener[:settings] = model_class.ps_msync_subscriber_settings
    end

    def log(message, kind = :info)
      PubSubModelSync::Config.log "#{message} ==> #{[data, attrs]}", kind
    end
  end
end
