# frozen_string_literal: true

module PubSubModelSync
  class RunSubscriber < Base
    attr_accessor :subscriber, :payload, :model

    delegate :settings, to: :subscriber

    # @param subscriber(Subscriber)
    # @param payload(Payload)
    def initialize(subscriber, payload)
      @subscriber = subscriber
      @payload = payload
    end

    def call
      klass_subscription? ? run_class_message : run_model_message
    end

    private

    def klass_subscription?
      subscriber.settings[:mode] == :klass
    end

    def run_class_message
      model_class = subscriber.klass.constantize
      model_class.ps_processing_payload = payload # TODO: review for parallel notifications
      call_action(model_class) if ensure_sync(model_class)
    end

    # support for: create, update, destroy
    def run_model_message
      @model = find_model
      model.ps_processing_payload = payload
      return unless ensure_sync(model)

      populate_model
      model.send(:ps_before_save_sync) if model.respond_to?(:ps_before_save_sync)
      call_action(model)
    end

    def ensure_sync(object)
      res = true
      res = false if settings[:if] && !parse_condition(settings[:if], object)
      res = false if settings[:unless] && parse_condition(settings[:unless], object)
      log("Cancelled save sync by subscriber condition : #{[payload.uuid]}") if !res && debug?
      res
    end

    def call_action(object)
      callback = settings[:to_action]
      callback.is_a?(Proc) ? object.instance_exec(payload.data, &callback) : call_action_method(object)
    end

    def call_action_method(object)
      method_name = settings[:to_action]
      method_name = :save! if %i[create update].include?(method_name.to_sym)
      method_name = :destroy! if method_name.to_sym == :destroy
      is_crud_action = %i[save! destroy!].include?(method_name)
      is_crud_action ? object.send(method_name) : object.send(method_name, payload.data)
    end

    def parse_condition(condition, object)
      proc_args = klass_subscription? ? [] : [object]
      case condition
      when Proc then condition.call(*proc_args)
      when Array then condition.all? { |method_name| object.send(method_name) }
      else # method name
        object.send(condition)
      end
    end

    def find_model
      model_class = subscriber.klass.constantize
      return model_class.ps_find_model(payload.data) if model_class.respond_to?(:ps_find_model)

      error_msg = 'No values provided for identifiers:'
      raise(StandardError, "#{error_msg} #{[settings[:id], payload]}") if model_identifiers.empty?

      model_class.where(model_identifiers).first_or_initialize
    end

    # @param mappings (Array<String,Symbol>) supports aliasing, sample: ["id", "full_name:name"]
    # @return (Hash) hash with the correct attr names and its values
    def parse_mapping(mappings)
      mappings.map do |prop|
        source, target = prop.to_s.split(':')
        key = (target || source).to_sym
        next unless payload.data.key?(source.to_sym)

        [key, payload.data[source.to_sym]]
      end.compact.to_h.symbolize_keys
    end

    # @return (Hash) hash including identifiers and its values
    def model_identifiers
      @model_identifiers ||= parse_mapping(Array(settings[:id]))
    end

    def populate_model
      values = parse_mapping(subscriber.mapping).except(model_identifiers.keys)
      values.each do |attr, value|
        model.send("#{attr}=", value)
      end
    end
  end
end
