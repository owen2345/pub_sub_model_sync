# frozen_string_literal: true

module PubSubModelSync
  class MockKafkaService
    class MockProducer
      def produce(*_args)
        true
      end

      def deliver_messages(*_args)
        true
      end

      def shutdown
        true
      end
    end

    class MockConsumer
      def each_message(*_args)
        true
      end

      def stop(*_args)
        true
      end

      def subscribe(*_args)
        true
      end
    end

    def producer(*_args)
      MockProducer.new
    end

    def consumer(*_args)
      MockConsumer.new
    end

    def close
      true
    end
  end
end
