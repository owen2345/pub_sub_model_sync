# frozen_string_literal: true

module PubSubModelSync
  class Subscriber
    attr_accessor :klass, :action, :attrs, :settings

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

    def eval_message(message)
      if settings[:direct_mode]
        run_class_message(message)
      else
        run_model_message(message)
      end
    end

    private

    def run_class_message(message)
      model_class = klass.constantize
      model_class.send(action, message)
    end

    # support for: create, update, destroy
    def run_model_message(message)
      model = find_model(message)
      if action == :destroy
        model.destroy!
      else
        populate_model(model, message)
        return if action == :update && !model.ps_subscriber_changed?(message)

        model.save!
      end
    end

    def find_model(message)
      model_class = klass.constantize
      if model_class.respond_to?(:ps_find_model)
        return model_class.ps_find_model(message)
      end

      model_class.where(model_identifiers(message)).first_or_initialize
    end

    def model_identifiers(message)
      identifiers = Array(settings[:id])
      identifiers.map { |key| [key, message[key.to_sym]] }.to_h
    end

    def populate_model(model, message)
      values = message.slice(*attrs)
      values.each do |attr, value|
        model.send("#{attr}=", value)
      end
    end
  end
end
