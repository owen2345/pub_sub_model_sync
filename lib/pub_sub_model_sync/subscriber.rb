# frozen_string_literal: true

module PubSubModelSync
  class Subscriber
    attr_accessor :klass, :action, :attrs, :settings
    attr_reader :payload

    # @param settings: (Hash) { id: :id, direct_mode: false,
    #                           from_klass: klass, from_action: action }
    def initialize(klass, action, attrs: nil, settings: {})
      def_settings = { id: :id, direct_mode: false,
                       from_klass: klass, from_action: action }
      @klass = klass
      @action = action
      @attrs = attrs
      @settings = def_settings.merge(settings)
    end

    def process!(payload)
      @payload = payload
      if settings[:direct_mode]
        run_class_message
      else
        run_model_message
      end
    end

    private

    def run_class_message
      model_class = klass.constantize
      model_class.send(action, payload.data)
    end

    # support for: create, update, destroy
    def run_model_message
      model = find_model
      return if model.ps_before_save_sync(payload) == :cancel

      if action == :destroy
        model.destroy!
      else
        populate_model(model)
        return if action == :update && !model.ps_subscriber_changed?(payload.data)

        model.save!
      end
    end

    def find_model
      model_class = klass.constantize
      return model_class.ps_find_model(payload.data) if model_class.respond_to?(:ps_find_model)

      model_class.where(model_identifiers).first_or_initialize
    end

    def model_identifiers
      identifiers = Array(settings[:id])
      identifiers.map { |key| [key, payload.data[key.to_sym]] }.to_h
    end

    def populate_model(model)
      values = payload.data.slice(*attrs)
      values.each do |attr, value|
        model.send("#{attr}=", value)
      end
    end
  end
end
