# **PubSubModelSync**
Automatically sync Model data and make calls between Rails applications using Google PubSub, RabbitMQ, or Apache Kafka Pub/Sub services.

Note: This gem is based on [MultipleMan](https://github.com/influitive/multiple_man) is now unmaintained.

- [**PubSubModelSync**](#pubsubmodelsync)
  - [**Features**](#features)
  - [**Installation**](#installation)
  - [**Configuration**](#configuration)
  - [**Notifications Diagram**](#notifications-diagram)
  - [**Basic Example**](#basic-example)
  - [**Advanced Example**](#advanced-example)
  - [**API**](#api)
    - [**Subscribers**](#subscribers)
      - [**Registering Subscription Callbacks**](#registering-subscription-callbacks)
      - [**Class Methods**](#class-methods)
      - [**Instance Methods**](#instance-methods)
    - [**Publishers**](#publishers)
      - [**Registering Publishing Callbacks**](#registering-publishing-callbacks)
      - [**Instance Methods**](#instance-methods-1)
      - [**Class Methods**](#class-methods-1)
      - [**Payload actions**](#payload-actions)
  - [**Testing with RSpec**](#testing-with-rspec)
  - [**Extra configurations**](#extra-configurations)
  - [**TODO**](#todo)
  - [**Q&A**](#qa)
  - [**Contributing**](#contributing)
  - [**License**](#license)
  - [**Code of Conduct**](#code-of-conduct)

## **Features**
- Sync CRUD operations between Rails apps. So, all changes made on App1, will be reflected on App2, App3.
    Example: If User is created on App1, this user will be created on App2 too with the accepted attributes.
- Ability to make class level communication
    Example: If User from App1 wants to generate_email, this can be listened on App2, App3, ... to make corresponding actions
- Change pub/sub service at any time
- Support for transactions: Permits to group all payloads with the same ordering_key and be processed in the same order they are published by the subscribers. 
  Grouping by ordering_key allows us to enable multiple workers in our Pub/Sub service(s), and still guarantee that related payloads will be processed in the correct order, despite of the multiple threads. 
  This thanks to the fact that Pub/Sub services will always send messages with the same `ordering_key` into the same worker/thread.
- Ability to send notifications to a specific topic or multiple topics

## **Installation**
Add this line to your application's Gemfile:
```ruby
gem 'pub_sub_model_sync'

gem 'google-cloud-pubsub', '>= 1.9' # to use google pub/sub service
gem 'bunny' # to use rabbit-mq pub/sub service
gem 'ruby-kafka' # to use apache kafka pub/sub service
```
And then execute: $ bundle install


## **Configuration**

- Configuration for google pub/sub (You need google pub/sub service account)
    ```ruby
    # initializers/pub_sub_config.rb
    PubSubModelSync::Config.service_name = :google
    PubSubModelSync::Config.project = 'google-project-id'
    PubSubModelSync::Config.credentials = 'path-to-the-config'
    PubSubModelSync::Config.topic_name = 'sample-topic' 
    PubSubModelSync::Config.subscription_name = 'my-app1'
    ```
    See details here:
    https://github.com/googleapis/google-cloud-ruby/tree/master/google-cloud-pubsub

- configuration for RabbitMq (You need rabbitmq installed)
    ```ruby
    PubSubModelSync::Config.service_name = :rabbitmq
    PubSubModelSync::Config.bunny_connection = 'amqp://guest:guest@localhost'
    PubSubModelSync::Config.topic_name = 'sample-topic'
    PubSubModelSync::Config.subscription_name = 'my-app2'
    ```
    See details here: https://github.com/ruby-amqp/bunny

- configuration for Apache Kafka (You need kafka installed)
    ```ruby
    PubSubModelSync::Config.service_name = :kafka
    PubSubModelSync::Config.kafka_connection = [["kafka1:9092", "localhost:2121"], { logger: Rails.logger }]
    PubSubModelSync::Config.topic_name = 'sample-topic'
    PubSubModelSync::Config.subscription_name = 'my-app3'
    ```
    See details here: https://github.com/zendesk/ruby-kafka

- Add publishers/subscribers to your models (See examples below)

- Start subscribers to listen for publishers (Only in the app that has subscribers)
    ```bash
    DB_POOL=20 bundle exec rake pub_sub_model_sync:start
    ```
    Note: You need more than 15 DB pools to avoid "could not obtain a connection from the pool within 5.000 seconds". https://devcenter.heroku.com/articles/concurrency-and-database-connections

- Check the service status with:
  ```PubSubModelSync::MessagePublisher.publish_data('Test message', {sample_value: 10}, :create)```

## **Notifications Diagram**
![Diagram](/docs/notifications-diagram.png?raw=true)

## **Basic Example**
```ruby
# App 1 (Publisher)
# attributes: name email age
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[id name email])
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[name]) # crud notifications
  ps_subscribe_custom(:say_welcome) # custom instance notification
  ps_class_subscribe(:greeting) # class notification

  def self.greeting(data)
    puts 'Class message called'
  end
  
  def say_welcome(data)
    UserMailer.deliver(id, data)
  end
end

# Samples
User.create(name: 'test user', email: 'sample@gmail.com') # Review your App 2 to see the created user (only name will be saved)
User.new(name: 'test user').ps_perform_sync(:create) # similar to above to perform sync on demand

PubSubModelSync::MessagePublisher.publish_model_data(my_user, { id:10, msg: 'Hello' }, :say_welcome, { as_klass: 'RegisteredUser' }) # custom model action notification
PubSubModelSync::MessagePublisher.publish_data(User, { msg: 'Hello' }, :greeting) # custom data notification
```

## **Advanced Example**
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[id:client_id name:full_name email], actions: %i[update], as_klass: 'Client', headers: { topic_name: ['topic1', 'topic N'] })

  def ps_skip_callback?(_action)
    false # here logic with action to skip push message
  end

  def ps_skip_sync?(_action)
      false # here logic with action to skip push message
    end
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  self.table_name = 'subscriber_users'
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[name], actions: %i[update], from_klass: 'Client', id: %i[client_id email])
  ps_class_subscribe(:greeting, from_action: :custom_greeting, from_klass: 'CustomUser')
  ps_subscribe_custom(:send_welcome, from_klass: 'CustomUser', id: :id, from_action: :say_welcome)
  alias_attribute :full_name, :name

  def self.greeting(data)
    puts 'Class message called through custom_greeting'
  end
  
  def send_welcome(data)
    UserMailer.deliver(id, data)
  end

  # def self.ps_find_model(data)
  #   where(email: data[:email], ...).first_or_initialize
  # end
end
```

## **API**
### **Subscribers**

#### **Registering Subscriptions**

- Configure class subscriptions
  ```ruby
  class MyModel < ActiveRecord::Base
    ps_class_subscribe(action_name, from_action: nil, from_klass: nil)
  end
  ```
  When Class receives the corresponding notification, `action` method will be called on the Class. Like: `User.action(data)`
  * `action_name`: (String|Sym/Optional) Action name
  * `from_klass`: (String/Optional) Source class name (Default `model.class.name`)
  * `from_action`: (Sym/Optional) Source method name. Default `action`

- Configure CRUD subscriptions
  ```ruby
  class MyModel < ActiveRecord::Base
    ps_subscribe(attrs, from_klass: nil, actions: nil, id: nil)
  end
  ```
  When model receives the corresponding notification, `action` method will be called on the model. Like: `model.destroy`
  * `attrs`: (Array/Required) Array of all attributes to be synced
  * `from_klass`: (String/Optional) Source class name (Default `model.class.name`)
  * `actions`: (Array/Optional, default: create/update/destroy) permit to customize action names
  * `id`: (Sym|Array/Optional, default: id) Attr identifier(s) to find the corresponding model

- Configure custom model subscriptions
  ```ruby
  class MyModel < ActiveRecord::Base
    ps_subscribe_custom(action, from_klass: name, id: :id, from_action: nil)
  end
  ```
  When model receives the corresponding notification, `action` method will be called on the model. Like: `model.action(data)`
  * `action`: (String/Required) Action name
  * `from_klass`: (String/Optional) Source class name (Default `model.class.name`)
  * `from_action`: (Sym/Optional) Source method name. Default `action`
  * `id`: (Sym|Array/Optional, default: id) Attr identifier(s) to find the corresponding model

- Perform custom actions before saving sync of the model (`:cancel` can be returned to skip sync)
  ```ruby
  class MyModel < ActiveRecord::Base
    def ps_before_save_sync(action, payload)
      # puts payload.data[:id]
    end
  end
  ```
  
- Configure a custom model finder (optional)
  ```ruby
  class MyModel < ActiveRecord::Base
    def ps_find_model(data)
      where(custom_finder: data[:custom_value]).first_or_initialize
    end
  end
  ```
  * `data`: (Hash) Data received from sync
  Must return an existent or a new model object

#### **Subscription helpers**
- Inspect all configured subscriptions
  ```ruby
  PubSubModelSync::Config.subscribers
  ```
- Manually process or reprocess a notification
  ```ruby
  payload = PubSubModelSync::Payload.new(data, attributes, headers)
  payload.process!
  ```


### **Publishers**

#### **Registering Publishers **
- Register CRUD publishers that will trigger configured notifications
  ```ruby
  class MyModel < ActiveRecord::Base
    ps_publish([:id, 'created_at:published_at', :full_name], actions: [:update], as_klass: nil, headers: { ordering_key: 'custom-key', topic_name: 'my-custom-topic' })
    def full_name
      [first_name, last_name].join(' ')
    end
  end
  ```
  * `attrs`: (Array/Required) Array of attributes to be published. Supports for:
    - aliases: permits to publish with different names, sample: "created_at:published_at" where "created_at" will be published as "published_at" 
    - methods: permits to publish method values as attributes, sample: "full_name"  
  * `actions`: (Array/Optional, default: %i[create update destroy]) permit to define action names
  * `as_klass`: (String/Optional) Output class name (Instead of the model class name, will use this value)
  * `headers`: (Hash/Optional) Notification settings which permit to customize the way and the target of the notification (Refer Payload.headers)
  

#### **Publishing notifications**
- CRUD notifications
  ```ruby 
    MyModel.create!(...) 
  ```    
  "Create" notification will be delivered with the configured attributes as the payload data

- Manual CRUD notifications
  ```ruby
  MyModel.ps_perform_sync(action, custom_data: {}, custom_headers: {})
  ```
  * `action`: (Sym) CRUD action name (create, update or destroy)
  * `custom_data`: custom_data (nil|Hash) If present custom_data will be used as the payload data. I.E. data generator will be ignored
  * `custom_headers`: (Hash, optional) override default headers. Refer `payload.headers`
  
- Class notifications
  ```ruby 
    PubSubModelSync::MessagePublisher.publish_data((klass, data, action, headers: )
  ```
  Publishes any data to be listened at a class level.
  - `klass`: (String) Class name to be used
  - `data`: (Hash) Data to be delivered
  - `action`: (Sym) Action name
  - `headers`: (Hash, optional) Notification settings (Refer Payload.headers)

- Model custom action notifications
  ```ruby 
    PubSubModelSync::MessagePublisher.publish_model_data(model, data, action, as_klass:, headers:)
  ```
  Publishes model custom action to be listened at an instance level.
  - `model`: (ActiveRecord) model owner of the data
  - `data`: (Hash) Data to be delivered
  - `action`: (Sym) Action name
  - `as_klass`: (String, optional) if not provided, `model.class.name` will be used instead
  - `headers`: (Hash, optional) Notification settings (Refer Payload.headers)
  
- Manually publish or republish a notification
    ```ruby
    payload = PubSubModelSync::Payload.new(data, attributes, headers)
    payload.publish!
    ```    

#### ** publishing callbacks**

- Prevent CRUD sync at model callback level (Called right after :after_create, :after_update, :after_destroy). 
  If returns "true", sync will be cancelled.
  ```ruby
  class MyModel < ActiveRecord::Base
    def ps_skip_callback?(action)
      # logic here
    end
  end
  ```

- Prevent CRUD sync before processing payload (Affects model.ps_perform_sync(...))).
  If returns "true", sync will be cancelled
    ```ruby
    class MyModel < ActiveRecord::Base
      def ps_skip_sync?(action)
        # logic here
      end
    end
    ```

- Do some actions before publishing a CRUD notification.
  If returns ":cancel", sync will be cancelled
  ```ruby
      class MyModel < ActiveRecord::Base
        def ps_before_sync(action, payload)
          # logic here
        end
      end
  ```

- Do some actions after CRUD notification was published.
  ```ruby
    class MyModel < ActiveRecord::Base
      def ps_after_sync(action, payload)
        # logic here
      end
    end
  ```


### **Payload**
Any notification before delivering is transformed as a Payload for a better portability. 

- Initialize  
  ```ruby
    payload = PubSubModelSync::Payload.new(data, attributes, headers)
  ```
  * `data`: (Hash) Data to be published or processed
  * `attributes`: (Hash) Includes class and method info
    - `action`: (String) action name
    - `klass`: (String) class name
  * `headers`: (Hash) Notification settings that defines how the notification will be processed or delivered. 
    - `key`: (String, optional) identifier of the payload, default: `<klass_name>/<action>` when class message, `<model.class.name>/<action>/<model.id>` when model message (Useful for caching techniques).
    - `ordering_key`: (String, optional): messages with the same key are processed in the same order they were delivered, default: `klass_name` when class message, `<model.class.name>/<model.id>` when model message
    - `topic_name`: (String|Array<String>, optional): Specific topic name to be used when delivering the message (default first topic from config).
    - `forced_ordering_key`: (String, optional): Will force to use this value as the `ordering_key`, even withing transactions. Default `nil`.
  
- Actions for payloads
  ```ruby
    payload.publish! # publishes notification data. It raises exception if fails and does not call ```:on_error_publishing``` callback
    payload.publish # publishes notification data. On error does not raise exception but calls ```:on_error_publishing``` callback
    payload.process! # process a notification data. It raises exception if fails and does not call ```.on_error_processing``` callback
    payload.publish # process a notification data. It does not raise exception if fails but calls ```.on_error_processing``` callback
  ```

## **Testing with RSpec**
- Config: (spec/rails_helper.rb)
    ```ruby

      # when using google service
      require 'pub_sub_model_sync/mock_google_service'
      config.before(:each) do
        google_mock = PubSubModelSync::MockGoogleService.new
        allow(Google::Cloud::Pubsub).to receive(:new).and_return(google_mock)
      end

      # when using rabbitmq service
      require 'pub_sub_model_sync/mock_rabbit_service'
      config.before(:each) do
        rabbit_mock = PubSubModelSync::MockRabbitService.new
        allow(Bunny).to receive(:new).and_return(rabbit_mock)
      end

      # when using apache kafka service
      require 'pub_sub_model_sync/mock_kafka_service'
      config.before(:each) do
        kafka_mock = PubSubModelSync::MockKafkaService.new
        allow(Kafka).to receive(:new).and_return(kafka_mock)
      end

    ```
- Examples:
    ```ruby
    # Subscriber
    it 'receive model message' do
      data = { name: 'name', id: 999 }
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: :create })
      payload.process!
      expect(User.where(id: data[:id]).any?).to be_truth
    end

    it 'receive class message' do
      data = { msg: 'hello' }
      action = :greeting
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: action })
      payload.process!
      expect(User).to receive(action)
    end

    # Publisher
    it 'publish model action' do
      publisher = PubSubModelSync::MessagePublisher
      user = User.create(name: 'name', email: 'email')
      expect(publisher).to receive(:publish_model).with(user, :create, anything)
    end
  
    it 'publishes the correct values' do
      exp_data = { email: 'email' }
      expect(publisher).to receive(:publish!).with(have_attributes(data: hash_including(exp_data)))
    end

    it 'publish class message' do
      publisher = PubSubModelSync::MessagePublisher
      data = {msg: 'hello'}
      action = :greeting
      PubSubModelSync::MessagePublisher.publish_data('User', data, action)
      expect(publisher).to receive(:publish_data).with('User', data, action)
    end
    ```

## **Extra configurations**
```ruby
config = PubSubModelSync::Config
config.debug = true
```
- `.topic_name = ['topic1', 'topic 2']`: (String|Array<String>)    
    Topic name(s) to be used to listen all notifications from when listening. Additional first topic name is used as the default topic name when publishing a notification. 
- `.subscription_name = "my-app-1"`:  (String, default Rails.application.name)     
    Subscriber's identifier which helps to: 
    * skip self messages
    * continue the sync from the last synced notification when service was restarted.
- ```.debug = true```
    (true/false*) => show advanced log messages
- ```.logger = Rails.logger```
    (Logger) => define custom logger
- ```.disabled_callback_publisher = ->(_model, _action) { false }```
    (true/false*) => if true, does not listen model callbacks for auto sync (Create/Update/Destroy)
- ```.on_before_processing = ->(payload, {subscriber:}) { puts payload }```
    (Proc) => called before processing received message (:cancel can be returned to skip processing)
- ```.on_success_processing = ->(payload, {subscriber:}) { puts payload }```
    (Proc) => called when a message was successfully processed
- ```.on_error_processing = ->(exception, {payload:, subscriber:}) { payload.delay(...).process! }```
    (Proc) => called when a message failed when processing (delayed_job or similar can be used for retrying)
- ```.on_before_publish = ->(payload) { puts payload }```
    (Proc) => called before publishing a message (:cancel can be returned to skip publishing)
- ```.on_after_publish = ->(payload) { puts payload }```
    (Proc) => called after publishing a message
- ```.on_error_publish = ->(exception, {payload:}) { payload.delay(...).publish! }```
    (Proc) => called when failed publishing a message (delayed_job or similar can be used for retrying)

## **TODO**
- Add alias attributes when subscribing (similar to publisher)
- Add flag ```model.ps_process_payload``` to retrieve the payload used to process the pub/sub sync
- Auto publish update only if payload has changed
- On delete, payload must only be composed by ids
- Improve transactions to exclude similar messages by klass and action. Sample:
    ```PubSubModelSync::MessagePublisher.transaction(key, { same_keys: :use_last_as_first|:use_last|:use_first_as_last|:keep*, same_data: :use_last_as_first*|:use_last|:use_first_as_last|:keep })```
- Add DB table to use as a shield to prevent publishing similar notifications and publish partial notifications (similar idea when processing notif)
- add callback: on_message_received(payload)

## **Q&A**
- I'm getting error "could not obtain a connection from the pool within 5.000 seconds"... what does this mean?
  This problem occurs because pub/sub dependencies (kafka, google-pubsub, rabbitmq) use many threads to perform notifications where the qty of threads is greater than qty of DB pools ([Google pubsub info](https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-pubsub/lib/google/cloud/pubsub/subscription.rb#L888))
  To fix the problem, edit config/database.yml and increase the quantity of ```pool: 20```
- How to retry failed syncs with sidekiq?
  ```ruby
    # lib/initializers/pub_sub_config.rb

    class PubSubRecovery
      include Sidekiq::Worker
      sidekiq_options queue: :pubsub, retry: 2, backtrace: true

      def perform(payload_data, action)
        payload = PubSubModelSync::Payload.from_payload_data(payload_data)
        payload.send(action)
      end
    end

    PubSubModelSync::Config.on_error_publish = lambda do |_e, data|
      PubSubRecovery.perform_async(data[:payload].to_h, :publish!)
    end
    PubSubModelSync::Config.on_error_processing = lambda do |_e, data|
      PubSubRecovery.perform_async(data[:payload].to_h, :process!)
    end
  ```

## **Contributing**

Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/pub_sub_model_sync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## **License**

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## **Code of Conduct**

Everyone interacting in the PubSubModelSync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pub_sub_model_sync/blob/master/CODE_OF_CONDUCT.md).
