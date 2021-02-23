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

      def mark_message_as_processed(*_args)
        true
      end
    end

    def producer(*_args)
      MockProducer.new
    end
    alias async_producer producer

    def consumer(*_args)
      MockConsumer.new
    end

    def topics
      []
    end

    def create_topic(_name)
      true
    end

    def close
      true
    end
  end
end
