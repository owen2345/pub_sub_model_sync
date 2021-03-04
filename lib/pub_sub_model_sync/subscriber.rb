# frozen_string_literal: true

module PubSubModelSync
  class Subscriber
    attr_accessor :klass, :action, :attrs, :settings, :identifiers
    attr_reader :payload

    # @param settings: (Hash) { id: :id, mode: :model|:klass|:custom_model,
    #                           from_klass: klass, from_action: action }
    def initialize(klass, action, attrs: nil, settings: {})
      @settings = { id: settings[:id] || :id,
                    mode: settings[:mode] || :klass,
                    from_klass: settings[:from_klass] || klass,
                    from_action: settings[:from_action] || action }
      @klass = klass
      @action = action
      @attrs = attrs
      @identifiers = Array(@settings[:id]).map(&:to_sym)
    end

    def process!(payload)
      @payload = payload
      case settings[:mode]
      when :klass then run_class_message
      when :custom_model then run_model_message(crud_action: false)
      else run_model_message
      end
    end

    private

    def run_class_message
      model_class = klass.constantize
      model_class.send(action, payload.data)
    end

    # support for: create, update, destroy
    def run_model_message(crud_action: true)
      model = find_model
      model.ps_processed_payload = payload
      return model.send(action, payload.data) if ensure_sync(model) && !crud_action

      if action == :destroy
        model.destroy! if ensure_sync(model)
      else
        populate_model(model)
        model.save! if ensure_sync(model)
      end
    end

    def ensure_sync(model)
      config = PubSubModelSync::Config
      cancelled = model.ps_before_save_sync(action, payload) == :cancel
      config.log("Cancelled sync with ps_before_save_sync: #{[payload]}") if cancelled && config.debug
      !cancelled
    end

    def find_model
      model_class = klass.constantize
      return model_class.ps_find_model(payload.data) if model_class.respond_to?(:ps_find_model)

      model_class.where(model_identifiers).first_or_initialize
    end

    def model_identifiers
      identifiers.map { |key| [key, payload.data[key.to_sym]] }.to_h
    end

    def populate_model(model)
      values = payload.data.slice(*attrs).except(*identifiers)
      values.each do |attr, value|
        model.send("#{attr}=", value)
      end
    end
  end
end
