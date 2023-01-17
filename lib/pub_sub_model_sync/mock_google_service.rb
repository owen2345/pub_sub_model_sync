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

      def on_error(&_block)
        true
      end

      def stop
        @stop ||= MockStop.new
      end
      alias stop! stop
    end

    class MockSubscription
      def listen(*_args)
        @listen ||= MockSubscriber.new
      end
    end

    class MockTopic
      def name
        'name'
      end

      def subscription(*_args)
        @subscription ||= MockSubscription.new
      end
      alias subscribe subscription

      def publish(*_args)
        true
      end

      def publish_async(*_args)
        yield(OpenStruct.new(succeeded?: true)) if block_given?
      end

      def resume_publish(_ordering_key)
        true
      end

      def enable_message_ordering!
        true
      end
    end

    def topic(*_args)
      @topic ||= MockTopic.new
    end
    alias create_topic topic
  end
end
