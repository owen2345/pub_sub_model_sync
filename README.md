# **PubSubModelSync**
![Rails badge](https://img.shields.io/badge/Rails-4+-success.png)
![Ruby badge](https://img.shields.io/badge/Ruby-2.4+-success.png)
![Production badge](https://img.shields.io/badge/Production-ready-success.png)

This gem permits to sync automatically model data, send custom notifications between multiple Rails applications by publishing notifications via pubsub (Google PubSub, RabbitMQ, or Apache Kafka). Out of the scope this gem includes transactions to keep Data consistency by processing notifications in the order they were delivered. 
These notifications use JSON format to easily be decoded by subscribers (Rails applications and even other languages) 

- [**PubSubModelSync**](#pubsubmodelsync)
  - [**Features**](#features)
  - [**Installation**](#installation)
  - [**Configuration**](#configuration)
  - [**Notifications Diagram**](#notifications-diagram)
  - [**Examples**](#examples)
    - [**Basic Example**](#basic-example)
    - [**Advanced Example**](#advanced-example)
  - [**API**](#api)
    - [**Subscribers**](#subscribers)
      - [**Registering Subscriptions**](#registering-subscriptions)
      - [**Subscription helpers**](#subscription-helpers)
    - [**Publishers**](#publishers)
      - [**Publishing notifications**](#publishing-notifications)
      - [**Publisher Helpers**](#publisher-helpers)
      - [**Publisher callbacks**](#publisher-callbacks)
    - [**Payload**](#payload)
  - [**Transactions**](#transactions)
  - [**Testing with RSpec**](#testing-with-rspec)
  - [**Extra configurations**](#extra-configurations)
  - [**TODO**](#todo)
  - [**Q&A**](#qa)
  - [**Contributing**](#contributing)
  - [**License**](#license)
  - [**Code of Conduct**](#code-of-conduct)

## **Features**
- Sync model data between Rails apps: All changes made on App1, will be immediately reflected on App2, App3, etc.
    Example: If User is created on App1, this user will be created on App2, App3 too with the accepted attributes.
- Ability to send class level communications
    Example: If App1 wants to send emails to multiple users, this can be listened on App2, to deliver corresponding emails
- Change pub/sub service at any time: Switch between rabbitmq, kafka, google pubsub  
- Support for transactions: Permits to keep data consistency between applications by processing notifications in the same order they were delivered.
- Ability to send notifications to a specific topic (single application) or multiple topics (multiple applications)

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

- More configurations: [here](#extra-configurations)

## **Notifications Diagram**
![Diagram](/docs/notifications-diagram.png?raw=true)

## **Examples**
### **Basic Example**
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_on_crud_event(:create) { ps_publish(:create, mapping: %i[id name email]) }
  ps_on_crud_event(:update) { ps_publish(:update, mapping: %i[id name email]) }
  ps_on_crud_event(:destroy) { ps_publish(:destroy, mapping: %i[id]) }  
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe([:create, :update, :destroy], %i[name email], id: :id) # crud notifications
end

# CRUD syncs
my_user = User.create(name: 'test user', email: 'sample@gmail.com') # Publishes `:create` notification (App 2 syncs the new user)
my_user.update(name: 'changed user') # Publishes `:update` notification (App2 updates changes)
my_user.destroy # Publishes `:destroy` notification (App2 destroys the corresponding user)
```

### **Advanced Example**
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_on_crud_event([:create, :update]) { ps_publish(:save, mapping: %i[id name:full_name email], as_klass: 'App1User', headers: { topic_name: %i[topic1 topic2] }) }
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(:save, %i[full_name:customer_name], id: [:id, :email], from_klass: 'App1User')  
  ps_subscribe(:send_welcome, %i[email], to_action: :send_email, if: ->(model) { model.email.present? })
  ps_class_subscribe(:batch_disable) # class subscription
  
  def send_email
    puts "sending email to #{email}"
  end
  
  def self.batch_disable(data)
    puts "disabling users: #{data[:ids]}"
  end
end
my_user = User.create(name: 'test user', email: 's@gmail.com') # Publishes `:save` notification as class name `App1User` (App2 syncs the new user)
my_user.ps_publish(:send_welcome, mapping: %i[id email]) # Publishes `:send_welcome` notification (App2 prints "sending email to...")
PubSubModelSync::MessagePublisher.publish_data(User, { ids: [my_user.id] }, :batch_disable) # Publishes class notification (App2 prints "disabling users..")
```

## **API**
### **Subscribers**

#### **Registering Subscriptions**
```ruby
  class MyModel < ActiveRecord::Base
    ps_subscribe(action, mapping, settings)
    ps_class_subscribe(action, settings)
  end
  ```
- Instance subscriptions: `ps_subscribe(action, mapping, settings)`     
  When model receives the corresponding notification, `action` or `to_action` method will be called on the model. Like: `model.destroy`
  - `action` (Symbol|Array<Symbol>) Only notifications with this action name will be processed by this subscription. Sample: save|create|update|destroy|<any_other_action>    
  - `mapping` (Array<String>) Data mapping from payload data into model attributes, sample: ["email", "full_name:name"] (Note: Only these attributes will be assigned/synced to the current model)    
    - `[email]` means that `email` value from payload will be assigned to `email` attribute from current model 
    - `[full_name:name]` means that `full_name` value from payload will be assigned to `name` attribute from current model 
  - `settings` (Hash<:from_klass, :to_action, :id, :if, :unless>)    
    - `from_klass:` (String, default current class): Only notifications with this class name will be processed by this subscription    
    - `to_action:` (Symbol|Proc, default `action`):        
      When Symbol: Model method to process the notification    
      When Proc: Block to process the notification    
    - `id:` (Symbol|Array<Symbol|String>, default: `:id`) identifier attribute(s) to find the corresponding model instance (Supports for mapping format)    
      Sample: `id: :id` will search for a model like: `model_class.where(id: payload.data[:id])`       
      Sample: `id: [:id, :email:user_email]` will search for a model like: `model_class.where(id: payload.data[:id], user_email: payload.data[:email])`       
    - `if:` (Symbol|Proc|Array<Symbol>) Method(s) or block called for the confirmation before calling the callback    
    - `unless:` (Symbol|Proc|Array<Symbol>) Method or block called for the negation before calling the callback    

- Class subscriptions: `ps_class_subscribe(action, settings)`     
  When current class receives the corresponding notification, `action` or `to_action` method will be called on the Class. Like: `User.hello(data)`
  * `action` (Symbol) Notification.action name
  * `settings` (Hash) refer ps_subscribe.settings except(:id)

- `ps_processing_payload` a class and instance variable that saves the current payload being processed

- (Only instance subscription) Perform custom actions before saving sync of the model (`:cancel` can be returned to skip sync)
  ```ruby
  class MyModel < ActiveRecord::Base
    def ps_before_save_sync
      # puts ps_processing_payload.data[:id]
    end
  end
  ```
  
- (Only instance subscription) Configure a custom model finder (optional)
  ```ruby
  class MyModel < ActiveRecord::Base
    def ps_find_model(data)
      where(custom_finder: data[:custom_value]).first_or_initialize
    end
  end
  ```
  * `data`: (Hash) Payload data received from sync
  Must return an existent or a new model object

#### **Subscription helpers**
- List all configured subscriptions
  ```ruby
  PubSubModelSync::Config.subscribers
  ```
- Manually process or reprocess a notification (useful when failed)
  ```ruby
  payload = PubSubModelSync::Payload.new(data, attributes, headers)
  payload.process!
  ```


### **Publishers**
```ruby
  class MyModel < ActiveRecord::Base
    ps_on_crud_event([:create, :update, :destroy], :method_publisher_name) # using method callback
    ps_on_crud_event([:create, :update, :destroy]) do |action| # using block callback
      ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: nil)
      ps_class_publish({}, action: :my_action, as_klass: nil, headers: {})
    end

    def method_publisher_name(action)
      ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: nil)
    end
  end
  ```

#### **Publishing notifications**

- `ps_on_crud_event(crud_actions, method_name = nil, &block)` Listens for CRUD events and calls provided `block` or `method` to process event callback
  - `crud_actions` (Symbol|Array<Symbol>) Crud event(s) to be observed (Allowed: `:create, :update, :destroy`)
  - `method_name` (Symbol, optional) method to be called to process action callback
  - `block` (Proc, optional) Block to be called to process action callback
  **Note1**: Due to rails callback ordering, this method uses `before_commit` callback when creating or updating models to ensure expected notifications order, sample:
    ```ruby
      user = User.create(name: 'asasas', posts_attributes: [{ title: 't1' }, { title: 't2' }])
    ```
    1: User notification     
    2: First post notification     
    3: Second post notification
           
  **Note2**: Due to rails callback ordering, this method uses `after_destroy` callback when destroying models to ensure the expected notifications ordering.
    ```ruby
      user.destroy
    ```   
    1: Second post notification     
    2: First post notification     
    3: User notification
   
- `ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: nil)` Delivers an instance notification via pubsub
  - `action` (Sym|String) Action name of the instance notification. Sample: create|update|destroy|<any_other_key>
  - `mapping:` (Array<String>, optional) Generates payload data using the provided mapper:
      - Sample: `["id", "name"]` will result into `{ id: <model.id>,  name: <model.name>}` 
      - Sample: `["id", "full_name:name"]` will result into `{ id: <model.id>,  name: <model.full_name>}`
  - `data:` (Hash|Symbol|Proc, optional)
    - When Hash: Data to be added to the final payload
    - When Symbol: Method name to be called to retrieve payload data (must return a `hash`, receives `:action` as arg)
    - When Proc: Block to be called to retrieve payload data (must return a `hash`, receives `:model, :action` as args)
  - `headers:` (Hash|Symbol|Proc, optional): Defines how the notification will be delivered and be processed (All available attributes in Payload.headers)
    - When Hash: Data that will be merged with default header values
    - When Symbol: Method name that will be called to retrieve header values (must return a hash, receives `:action` arg)
    - When Proc: Block to be called to retrieve header values (must return a `hash`, receives `:model, :action` as args)
  - `as_klass:` (String, default current class name): Output class name used instead of current class name
  
- `ps_class_publish` Delivers a  Class notification via pubsub
  - `data` (Hash): Data of the notification
  - `action` (Symbol): action  name of the notification
  - `as_klass:` (String, default current class name): Class name of the notification
  - `headers:` (Hash, optional): header settings (More in Payload.headers)
  
#### **Publisher helpers**
- Publish a class notification from anywhere
  ```ruby 
    PubSubModelSync::MessagePublisher.publish_data(klass, data, action, headers: )
  ```
  - `klass`: (String) Class name to be used
  - Refer to `ps_class_publish` except `as_klass:`

- Manually publish or republish a notification (useful when failed)
  ```ruby
  payload = PubSubModelSync::Payload.new(data, attributes, headers)
  payload.publish!
  ```

#### **Publisher callbacks**
- Prevent delivering a notification (called before building payload)
  If returns "true", will not publish notification
    ```ruby
    class MyModel < ActiveRecord::Base
      def ps_skip_publish?(action)
        # logic here
      end
    end
    ```

- Do some actions before publishing notification.
  If returns ":cancel", notification will not be delivered
  ```ruby
      class MyModel < ActiveRecord::Base
        def ps_before_publish(action, payload)
          # logic here
        end
      end
  ```

- Do some actions after notification was delivered.
  ```ruby
    class MyModel < ActiveRecord::Base
      def ps_after_publish(action, payload)
        # logic here
      end
    end
  ```


### **Payload**
Any notification before delivering is transformed as a Payload for a better portability. 

- Attributes  
  * `data`: (Hash) Data to be published or processed
  * `info`: (Hash) Notification info
    - `action`: (String) Notification action name
    - `klass`: (String) Notification class name
    - `mode`: (Symbol: `:model`|`:class`) Kind of notification
  * `headers`: (Hash) Notification settings that defines how the notification will be processed or delivered. 
    - `key`: (String, optional) identifier of the payload, default: `<klass_name>/<action>` when class message, `<model.class.name>/<action>/<model.id>` when model message (Useful for caching techniques).
    - `ordering_key`: (String, optional): messages with the same value are processed in the same order they were delivered, default: `klass_name` when class message, `<model.class.name>/<model.id>` when instance message
    - `topic_name`: (String|Array<String>, optional): Specific topic name (can be seen as a channel) to be used when delivering the message (default first topic from config).
    - `forced_ordering_key`: (String, optional): Will force to use this value as the `ordering_key`, even withing transactions. Default `nil`.
  
- Actions
  ```ruby
    payload.publish! # publishes notification data. It raises exception if fails and does not call ```:on_error_publishing``` callback
    payload.publish # publishes notification data. On error does not raise exception but calls ```:on_error_publishing``` callback
    payload.process! # process a notification data. It raises exception if fails and does not call ```.on_error_processing``` callback
    payload.publish # process a notification data. It does not raise exception if fails but calls ```.on_error_processing``` callback
  ```

## **Transactions**   
  This Gem supports to publish multiple notifications to be processed in the same order they are published.   
  * Crud syncs auto includes transactions which works as the following:
    ```ruby
    class User
      ps_on_crud_event(:create) { ps_publish(:create, mapping: %i[id name]) }
      has_many :posts
      accepts_nested_attributes_for :posts
    end
    
    class Post
      belongs_to :user
      ps_on_crud_event(:create) { ps_publish(:create, mapping: %i[id title]) }
    end
    
    User.create!(name: 'test', posts_attributes: [{ title: 'Post 1' }, { title: 'Post 2' }])
    ```
    When user is created, `User`:`:save` notification is published with the ordering_key = `User/<user_id>`.   
    Posts created together with the user model publishes `Post`:`:save` notification each one using its parents (user model) `ordering_key`.   
    By this way parent notification and all inner notifications are processed in the same order they were published (includes notifications from callbacks like `ps_before_publish`).
        
    **Note**: When any error is raised when saving user or posts, the transaction is cancelled and thus all notifications wont be delivered (customizable by `PubSubModelSync::Config.transactions_use_buffer`).    
  
  - Manual transactions   
    `PubSubModelSync::MessagePublisher::transaction(key, max_buffer: , &block)`
    - `key` (String|nil) Key used as the ordering key for all inner notifications (When nil, will use `ordering_key` of the first notification)  
    - `max_buffer:` (Boolean, default: `PubSubModelSync::Config.transactions_max_buffer`)     
        If true: will save all notifications and deliver all them when transaction has successfully finished. If transaction has failed, then all saved notifications will be discarded (not delivered).    
        If false: will deliver all notifications immediately (no way to rollback notifications if transaction has failed)  
    Sample:
    ```ruby
      PubSubModelSync::MessagePublisher::transaction('my-custom-key') do
        user = User.create(name: 'test') # `User`:`:create` notification
        post = Post.create(title: 'sample') # `Post`:`:create` notification
        PubSubModelSync::MessagePublisher.publish_data(User, { ids: [user.id] }, :send_welcome) # `User`:`:send_welcome` notification
      end
    ```
    All notifications uses `ordering_key: 'my-custom-key'` and will be processed in the same order they were published.

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
  
      # 
      config.before(:each) do
        # **** disable payloads generation, sync callbacks to improve tests speed 
        allow(PubSubModelSync::MessagePublisher).to receive(:publish_data) # disable class level notif
        allow(PubSubModelSync::MessagePublisher).to receive(:publish_model) # disable instance level notif
        
        # **** when testing model syncs, it can be re enabled by:
        # before do
        #  allow(PubSubModelSync::MessagePublisher).to receive(:publish_data).and_call_original
        #   allow(PubSubModelSync::MessagePublisher).to receive(:publish_model).and_call_original
        # end
      end
    ```
- Examples:
    ```ruby
    # Subscriber
    it 'receive model notification' do
      data = { name: 'name', id: 999 }
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: :create })
      payload.process!
      expect(User.where(id: data[:id])).to be_any
    end

    it 'receive class notification' do
      data = { msg: 'hello' }
      action = :greeting
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: action, mode: :klass })
      payload.process!
      expect(User).to receive(action)
    end

    # Publisher
    it 'publishes model notification' do
      publisher = PubSubModelSync::MessagePublisher
      user = User.create(name: 'name', email: 'email')
      expect(publisher).to receive(:publish_model).with(user, :create, anything)
    end
  
    it 'publishes the correct values in the payload' do
      exp_data = { email: 'email' }
      expect(publisher).to receive(:publish!).with(have_attributes(data: hash_including(exp_data)))
    end

    it 'publishes class notification' do
      publisher = PubSubModelSync::MessagePublisher
      user = User.create(name: 'name', email: 'email')
      user.ps_class_publish({msg: 'hello'}, action: :greeting)
      expect(publisher).to receive(:publish_data).with('User', data, :greeting)
    end
    ```

## **Extra configurations**
```ruby
config = PubSubModelSync::Config
config.debug = true
```
- `.topic_name = ['topic1', 'topic 2']`: (String|Array<String>)    
    Topic name(s) to be used to listen all notifications from when listening. Additionally first topic name is used as the default topic name when publishing a notification. 
- `.subscription_name = "my-app-1"`:  (String, default Rails.application.name)     
    Subscriber's identifier which helps to: 
    * skip self messages
    * continue the sync from the last synced notification when service was restarted.
- `.default_topic_name = "my_topic"`: (String|Array<String>, optional(default first topic from `topic_name`))     
    Topic name used as the default topic if not defined in the payload when publishing a notification
- ```.debug = true```
    (true/false*) => show advanced log messages
- ```.logger = Rails.logger```
    (Logger) => define custom logger
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
- ```.transactions_max_buffer = 100``` (Integer) Once this quantity of notifications is reached, then all notifications will immediately be delivered.    
    Note: There is no way to rollback delivered notifications if current transaction fails
- ```.enable_rails4_before_commit = true``` (true*|false) When false will disable rails 4 hack compatibility and then CRUD notifications will be prepared using `after_commit` callback instead of `before_commit` which will not rollback sql transactions if fails.

## **TODO**
- Auto publish update only if payload has changed (see ways to compare previous payload vs new payload)
- Improve transactions to exclude similar messages by klass and action. Sample:
    ```PubSubModelSync::MessagePublisher.transaction(key, { same_keys: :use_last_as_first|:use_last|:use_first_as_last|:keep*, same_data: :use_last_as_first*|:use_last|:use_first_as_last|:keep })```
- Add DB table to use as a shield to prevent publishing similar notifications and publish partial notifications (similar idea when processing notif)
- Last notification is not being delivered immediately in google pubsub (maybe force with timeout 10secs and service.deliver_messages)
- Update folder structure
- Support for blocks in ps_publish and ps_subscribe
- Services support to deliver multiple payloads from transactions

## **Q&A**
- I'm getting error "could not obtain a connection from the pool within 5.000 seconds"... what does this mean?
  This problem occurs because pub/sub dependencies (kafka, google-pubsub, rabbitmq) uses many threads to perform notifications where the qty of threads is greater than qty of DB pools ([Google pubsub info](https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-pubsub/lib/google/cloud/pubsub/subscription.rb#L888))
  To fix the problem, edit config/database.yml and increase the quantity of ```pool: ENV['DB_POOL'] || 5``` and `DB_POOL=20 bundle exec rake pub_sub_model_sync:start`
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

## **Running tests**
- `docker-compose run test`
- `docker-compose run test bash -c "rubocop"`