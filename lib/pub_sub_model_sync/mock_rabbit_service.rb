# frozen_string_literal: true

module PubSubModelSync
  class MockRabbitService
    class MockTopic
      def publish(*_args)
        true
      end
    end

    class MockQueue
      def bind(*_args)
        true
      end

      def subscribe(*_args)
        true
      end

      def name
        'name'
      end
    end

    class MockChannel
      def queue(*_args)
        @queue ||= MockQueue.new
      end
      alias fanout queue

      def topic(*_args)
        @topic ||= MockTopic.new
      end

      def close
        true
      end
    end

    def create_channel(*_args)
      @create_channel ||= MockChannel.new
    end
    alias channel create_channel

    def start
      true
    end

    def close
      true
    end
  end
end
