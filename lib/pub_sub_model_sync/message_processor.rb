# frozen_string_literal: true

module PubSubModelSync
  class MessageProcessor
    attr_accessor :data, :settings, :message_id

    # @param data (Hash): any hash value to deliver
    def initialize(data, klass, action)
      @data = data
      @settings = { klass: klass, action: action }
      @message_id = [klass, action, Time.now.hash].join('-')
    end

    def process
      @failed = false
      log "processing message: #{[data, settings]}"
      listeners = filter_listeners
      return log 'Skipped: No listeners' unless listeners.any?

      eval_message(listeners)
      log 'processed message' unless @failed
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
      model_class = listener[:klass].constantize
      model_class.send(listener[:action], data)
    rescue => e
      log("Error listener (#{listener}): #{e.message}", :error)
      @failed = true
    end

    # support for: create, update, destroy
    def call_listener(listener)
      model = find_model(listener)
      if settings[:action].to_sym == :destroy
        model.destroy!
      else
        populate_model(model, listener)
        model.save!
      end
    rescue => e
      log("Error listener (#{listener}): #{e.message}", :error)
      @failed = true
    end

    def find_model(listener)
      model_class = listener[:klass].constantize
      if model_class.respond_to?(:ps_find_model)
        return model_class.ps_find_model(data, settings)
      end

      model_class.where(model_identifiers(listener)).first_or_initialize
    end

    def model_identifiers(listener)
      identifiers = listener[:settings][:id]
      identifiers = [identifiers] unless identifiers.is_a?(Array)
      identifiers.map { |key| [key, data[key.to_sym]] }.to_h
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
        listener[:as_klass].to_s == settings[:klass].to_s &&
          listener[:as_action].to_s == settings[:action].to_s
      end
    end

    def log(message, kind = :info)
      PubSubModelSync::Config.log "(ID: #{message_id}) #{message}", kind
    end
  end
end
