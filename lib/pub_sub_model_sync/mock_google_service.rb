# frozen_string_literal: true

module PubSubModelSync
  class MockGoogleService
    class MockStop
      def wait!
        true
      end
    end
    class MockSubscriber
      def start
        true
      end

      def stop
        @stop ||= MockStop.new
      end
    end
    class MockSubscription
      def listen(*_args)
        @listen ||= MockSubscriber.new
      end
    end
    class MockTopic
      def subscription(*_args)
        @subscription ||= MockSubscription.new
      end
      alias subscribe subscription

      def publish(*_args)
        true
      end
    end
    def topic(*_args)
      @topic ||= MockTopic.new
    end
    alias create_topic topic
  end
end
