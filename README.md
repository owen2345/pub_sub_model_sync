# **PubSubModelSync**
![Rails badge](https://img.shields.io/badge/Rails-4+-success.png)
![Ruby badge](https://img.shields.io/badge/Ruby-2.4+-success.png)
![Production badge](https://img.shields.io/badge/Production-ready-success.png)

This gem permits to sync automatically models and custom data between multiple Rails applications by publishing notifications via pubsub (Google PubSub, RabbitMQ, or Apache Kafka) and automatically processed by all connected applications. Out of the scope, this gem includes transactions to keep Data consistency by processing notifications in the order they were delivered.     
These notifications use JSON format to easily be decoded by subscribers (Rails applications and even other languages, soon for [Cristal-lang](https://crystal-lang.org/)) 

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
- Ability to send instance and class level notifications    
    Example: If App1 wants to send emails to multiple users, this can be listened on App2, to deliver corresponding emails
- Change pub/sub service at any time: Switch between rabbitmq, kafka, google pubsub  
- Support for transactions: Permits to keep data consistency between applications by processing notifications in the same order they were delivered (auto included in models transactions).
- Ability to send notifications to a specific topic (single application) or multiple topics (multiple applications)

## **Installation**
Add this line to your application's Gemfile:
```ruby
gem 'pub_sub_model_sync', '>= 1.9.3'

gem 'google-cloud-pubsub', '>= 2.14.0' # to use google pub/sub service. For old rails apps ('>= 1.9', '<= 2.9.2')
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
    PubSubModelSync::Config.credentials = 'path-to-google-config.json'
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

  *Important: The `topic_name` must be the same for all applications, so that, the apps connect to the same topic*

- Add publishers/subscribers to your models (See examples below)

- Start subscribers to listen for publishers (Only in the app that has subscribers)
    ```bash
      DB_POOL=20 bundle exec rake pub_sub_model_sync:start
    ```
    Note: You need more than 15 DB pools to avoid "could not obtain a connection from the pool within 5.000 seconds". https://devcenter.heroku.com/articles/concurrency-and-database-connections

- Check the service status with:
  ```ruby
    PubSubModelSync::Payload.new({ my_data: 'here' }, { klass: 'MyClass', action: :sample_action }).publish!
  ```

- More configurations: [here](#extra-configurations)

## **Notifications Diagram**
![Diagram](/docs/notifications-diagram.png?raw=true)

## **Examples**
See sample apps in [/samples](/samples/)   
### **Basic Example**
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_after_action(:create) { ps_publish(:create, mapping: %i[id name email]) }
  ps_after_action(:update) { ps_publish(:update, mapping: %i[id name email]) }
  ps_after_action(:destroy) { ps_publish(:destroy, mapping: %i[id]) }  
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe([:create, :update, :destroy], %i[name email], id: :id) # crud notifications
end

# CRUD syncs
my_user = User.create!(name: 'test user', email: 'sample@gmail.com') # Publishes `:create` notification (App 2 syncs the new user)
my_user.update!(name: 'changed user') # Publishes `:update` notification (App2 updates changes on user with the same id)
my_user.destroy! # Publishes `:destroy` notification (App2 destroys the corresponding user)
```

### **Advanced Example**
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_after_action([:create, :update]) do |action| 
    ps_publish(action, mapping: %i[name:full_name email], as_klass: 'App1User', headers: { topic_name: %i[topic1 topic2] })
  end
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_subscribe([:create, :update], %i[full_name:customer_name], id: :email, from_klass: 'App1User')  
  ps_subscribe(:send_welcome, %i[email], id: :email, to_action: :send_email, if: ->(model) { model.email.present? })
  ps_class_subscribe(:batch_disable) # class subscription
  
  def send_email
    puts "sending email to #{email}"
  end
  
  def self.batch_disable(data)
    puts "disabling users: #{data[:ids]}"
  end
end
my_user = User.create!(name: 'test user', email: 's@gmail.com') # Publishes `:create` notification with classname `App1User` (App2 syncs the new user)
my_user.ps_publish(:send_welcome, mapping: %i[id email]) # Publishes `:send_welcome` notification (App2 prints "sending email to...")
PubSubModelSync::Payload.new({ ids: [my_user.id] }, { klass: 'User', action: :batch_disable, mode: :klass }).publish! # Publishes class notification (App2 prints "disabling users..")
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
- Instance subscriptions: `ps_subscribe(action, mapping, settings, &block)`     
  When model receives the corresponding notification, `action` or `to_action` method will be called on the model. Like: `model.destroy`
  - `action` (Symbol|Array<Symbol>) Only notifications with this action name will be processed by this subscription. Sample: save|create|update|destroy|<any_other_action>    
  - `mapping` (Array<String>) Data mapping from payload data into model attributes, sample: ["email", "full_name:name"] (Note: Only these attributes will be assigned/synced to the current model)    
    - `[email]` means that `email` value from payload will be assigned to `email` attribute from current model 
    - `[full_name:name]` means that `full_name` value from payload will be assigned to `name` attribute from current model 
  - `settings` (Hash<:from_klass, :to_action, :id, :if, :unless>)    
    - `from_klass:` (String, default current class): Only notifications with this class name will be processed by this subscription    
    - `to_action:` (Symbol|Proc, default `action`):        
      When Symbol: Model method to process the notification, sample: `def my_method(data)...end`    
      When Proc: Block to process the notification, sample: `{|data| ... }`    
    - `id:` (Symbol|Array<Symbol|String>, default: `:id`) identifier attribute(s) to find the corresponding model instance (Supports for mapping format)    
      Sample: `id: :id` will search for a model like: `model_class.where(id: payload.data[:id])`       
      Sample: `id: [:id, :email:user_email]` will search for a model like: `model_class.where(id: payload.data[:id], user_email: payload.data[:email])`       
    - `if:` (Symbol|Proc|Array<Symbol>) Method(s) or block called for the confirmation before calling the callback    
    - `unless:` (Symbol|Proc|Array<Symbol>) Method or block called for the negation before calling the callback
  - `&block` Block to be used as the callback method (ignored if `:to_action` is present). Sample: `ps_subscribe(:send_welcome, %i[email]) { |_data| puts model.email }`    

- Class subscriptions: `ps_class_subscribe(action, settings, &block)`     
  When current class receives the corresponding notification, `action` or `to_action` method will be called on the Class. Like: `User.hello(data)`
  * `action` (Symbol) Notification.action name
  * `settings` (Hash) refer ps_subscribe.settings except(:id)
  * `&block` Block to be used as the callback method (ignored if `:to_action` is present). Sample: `ps_class_subscribe(:send_welcome) { |data| puts data }`

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
- Process or reprocess a notification
  ```ruby
    payload = PubSubModelSync::Payload.new(data, attributes, headers)
    payload.process!
  ```


### **Publishers**
```ruby
  class MyModel < ActiveRecord::Base
    ps_after_action([:create, :update, :destroy], :method_publisher_name) # using method callback
    ps_after_action([:create, :update, :destroy]) do |action| # using block callback
      ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: nil)
      ps_class_publish({}, action: :my_action, as_klass: nil, headers: {})
    end

    def method_publisher_name(action)
      ps_publish(action, data: {}, mapping: [], headers: {}, as_klass: nil)
    end
  end
  ```

#### **Publishing notifications**

- `ps_after_action(crud_actions, method_name = nil, &block)` Listens for CRUD events and calls provided `block` or `method` to process event callback
  - `crud_actions` (Symbol|Array<Symbol>) Crud event(s) to be observed (Allowed: `:create, :update, :destroy`)
  - `method_name` (Symbol, optional) method to be called to process action callback, sample: `def my_method(action) ... end`
  - `block` (Proc, optional) Block to be called to process action callback, sample: `{ |action| ... }`     
  
  **Note1**: Due to rails callback ordering, this method uses `after_commit on: action {...}` callback when creating or updating models to ensure expected notifications order (More details [**here**](#transactions)).    
  **Note2**: Due to rails callback ordering, this method uses `after_destroy` callback when destroying models to ensure the expected notifications order.    
   
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
  
- `ps_class_publish(data, action:, as_klass: nil, headers: {})` Delivers a  Class notification via pubsub
  - `data` (Hash): Data of the notification
  - `action` (Symbol): action  name of the notification
  - `as_klass:` (String, default current class name): Class name of the notification
  - `headers:` (Hash, optional): header settings (More in Payload.headers)

- `ps_perform_publish(action = :create, parents_actions: false)` Permits to perform manually the callback of a specific `ps_after_action`
  - `action` (Symbol, default: :create) Only :create|:update|:destroy
  - `parents_actions` (Boolean, default: false) When `true`, includes inherited PubSub-callbacks from parent classes
    
  
#### **Publisher helpers**
- Publish or republish a notification
  ```ruby
    payload = PubSubModelSync::Payload.new(data, attributes, headers)
    payload.publish!
  ```

#### **Publisher callbacks**

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
    - `ordering_key`: (String, optional): notifications with the same `ordering_key` are processed in the same order they were delivered, default: `<model.class.name>/<model.id>` when instance notification and `klass_name` when class notification.    
      Note: Final `ordering_key` is calculated as: `payload.headers[:forced_ordering_key] || current_transaction&.key || payload.headers[:ordering_key]`         
    - `topic_name`: (String|Array<String>, optional): Specific topic name where to deliver the notification (default `PubSubModelSync::Config.topic_name`).
    - `forced_ordering_key`: (String, optional): Overrides `ordering_key` with the provided value even withing transactions. Default `nil` (if `true`, prevails the payload's `ordering_key`).
    - `target_app_key`: (String, optional): Allows to send the notification to a specific app (includes the application key, separated by comma when multiple apps). Default `nil`.
    - `cache` (Boolean | Hash, Default false) Cache settings   
        - `true`: Skip publishing similar payloads
        - `Hash<required: Array<Symbol>>`: Same as `true` and enables payload optimization to exclude unchanged non important attributes. Sample: `{ required: %i[id email] }`
    
    ** Read ONLY **    
    - `internal_key`: Internal identifier of the payload, default: `<model.class.name>/<action>/<model.id>` when model notification and `<klass_name>/<action>` when class notification (Useful for caching techniques).
    - `app_key`: (Auto calculated): Name of the application who delivered the notification.
    - `uuid`: (Auto calculated): Unique notification identifier (Very useful when debugging).   
Note: To reduce Payload size, some header info are not delivered (Enable debug mode to deliver all payload info). 
  
- Actions
  ```ruby
    payload.publish! # publishes notification data. It raises exception if fails and does not call ```:on_error_publishing``` callback
    payload.publish # publishes notification data. On error does not raise exception but calls ```:on_error_publishing``` callback
    payload.process! # process a notification data. It raises exception if fails and does not call ```.on_error_processing``` callback
    payload.process # process a notification data. It does not raise exception if fails but calls ```.on_error_processing``` callback
    payload.retry_publish! # allows to retry publishing a failed payload (All callbacks are ignored)
  ```

## **Transactions**   
  This Gem supports to publish multiple notifications to be processed in the same order they are published.   
  * Crud syncs auto includes transactions which works as the following:
    ```ruby
    class User
      ps_after_action([:create, :update, :destroy]) { |action| ps_publish(action, mapping: %i[id name]) }
      has_many :posts, dependent: :destroy
      accepts_nested_attributes_for :posts
    end
    
    class Post
      belongs_to :user
      ps_after_action([:create, :update, :destroy]) { |action| ps_publish(action, mapping: %i[id user_id title]) }
    end
    ```
    - When created (all notifications use the same ordering_key to be processed in the same order)
      ```ruby
        user = User.create!(name: 'test', posts_attributes: [{ title: 'Post 1' }, { title: 'Post 2' }])
        # notification #1 => <Payload data: {id: 1, name: 'sample'}, info: { klass: 'User', action: :create, mode: :model }, headers: { ordering_key = `User/1` }>
        # notification #2 => <Payload data: {id: 1, title: 'Post 1', user_id: 1}, info: { klass: 'Post', action: :create, mode: :model }, headers: { ordering_key = `User/1` }>
        # notification #3 => <Payload data: {id: 2, title: 'Post 2', user_id: 1}, info: { klass: 'Post', action: :create, mode: :model }, headers: { ordering_key = `User/1` }>
      ```
    - When updated (all notifications use the same ordering_key to be processed in the same order)
      ```ruby
        user.update!(name: 'changed', posts_attributes: [{ id: 1, title: 'Post 1C' }, { id: 2, title: 'Post 2C' }])
        # notification #1 => <Payload data: {id: 1, name: 'changed'}, info: { klass: 'User', action: :update, mode: :model }, headers: { ordering_key = `User/1` }>
        # notification #2 => <Payload data: {id: 1, title: 'Post 1C', user_id: 1}, info: { klass: 'Post', action: :update, mode: :model }, headers: { ordering_key = `User/1` }>
        # notification #3 => <Payload data: {id: 2, title: 'Post 2C', user_id: 1}, info: { klass: 'Post', action: :update, mode: :model }, headers: { ordering_key = `User/1` }>
      ```
    - When destroyed (all notifications use the same ordering_key to be processed in the same order)   
      **Note**: The notifications order were reordered in order to avoid inconsistency in other apps 
      ```ruby
      user.destroy!
      # notification #1 => <Payload data: {id: 1, title: 'Post 1C', user_id: 1}, info: { klass: 'Post', action: :destroy, mode: :model }>
      # notification #2 => <Payload data: {id: 2, title: 'Post 2C', user_id: 1}, info: { klass: 'Post', action: :destroy, mode: :model }>
      # notification #3 => <Payload data: {id: 1, name: 'changed'}, info: { klass: 'User', action: :destroy, mode: :model }>
      ```
    By this way parent notification and all inner notifications are processed in the same order they were published (includes notifications from callbacks like `ps_before_publish`).
        
    **Note**: When any error is raised when saving user or posts, the transaction is cancelled and thus all notifications wont be delivered (customizable by `PubSubModelSync::Config.transactions_use_buffer`).    
  
  - Manual transactions   
    `PubSubModelSync::MessagePublisher::transaction(key, headers: { target_app_key: 'my_other_app_key' } &block)`
    - `key` (String|nil) Key used as the ordering_key for all inner notifications (When nil, will use `ordering_key` of the first notification)
    - `headers:` (Hash) Header settings to be added to each Payload's header inside this transaction     
    Sample:
    ```ruby
      PubSubModelSync::MessagePublisher::transaction('my-custom-key', headers: { key: 'my-key' }) do
        user = User.create(name: 'test') # `User`:`:create` notification
        post = Post.create(title: 'sample') # `Post`:`:create` notification
        PubSubModelSync::Payload.new({ ids: [user.id] }, { klass: 'User', action: :send_welcome, mode: :klass }).publish! # `User`:`:send_welcome` notification
      end
    ```
    All notifications uses `ordering_key: 'my-custom-key'` and will be processed in the same order they were published (Payload headers will include `key="my-key"`).

## **Testing with RSpec**
- Config: (spec/rails_helper.rb)
  ```ruby
      config.before(:each) do
        # disable delivering notifications to pubsub
        allow(PubSubModelSync::MessagePublisher).to receive(:connector_publish)
        # disable all models sync by default (reduces testing time by avoiding to build payload data)
        allow(PubSubModelSync::MessagePublisher).to receive(:publish_model)
      end
    
      # enable all models sync only for tests that includes 'sync: true'
      config.before(:each, sync: true) do
        allow(PubSubModelSync::MessagePublisher).to receive(:publish_model).and_call_original
      end
      
      # Only when using database cleaner in old versions of rspec (enables after_commit callback)
      # config.before(:each, truncate: true) do
      #   DatabaseCleaner.strategy = :truncation
      # end
  ```
- Examples:
  - **Publisher**    
    Note: **Do not forget to include 'sync: true'** to enable publishing pubsub notifications
    ```ruby
      describe 'When publishing sync', truncate: true, sync: true do
        it 'publishes user notification when created' do
          expect_publish_notification(:create, klass: 'User')
          create(:user)
        end
        
        it 'publishes user notification with all defined data' do
          user = build(:user)
          data = PubSubModelSync::PayloadBuilder.parse_mapping_for(user, %i[id name:full_name email])
          data[:id] = be_a(Integer)
          expect_publish_notification(:create, klass: 'User', data: data)
          user.save!
        end
        
        it 'publishes user notification when created' do
          email = 'Newemail@gmail.com'
          user = create(:user)
          expect_publish_notification(:update, klass: 'User', data: { id: user.id, email: email })
          user.update!(email: email)
        end
        
        it 'publishes user notification when created' do
          user = create(:user)
          expect_publish_notification(:destroy, klass: 'User', data: { id: user.id })
          user.destroy!
        end
        
        private
        
        # @param action (Symbol)
        # @param klass (String, default described_class name)
        # @param data (Hash, optional) notification data
        # @param info (Hash, optional) notification info
        # @param headers (Hash, optional) notification headers
        def expect_publish_notification(action, klass: described_class.to_s, data: {}, info: {}, headers: {})
          publisher = PubSubModelSync::MessagePublisher
          exp_data = have_attributes(data: hash_including(data),
                                     info: hash_including(info.merge(klass: klass, action: action)),
                                     headers: hash_including(headers))
          allow(publisher).to receive(:publish!).and_call_original
          expect(publisher).to receive(:publish!).with(exp_data)
        end
      end
    ```   
  - **Subscriber**    
  ```ruby
  
  describe 'when syncing data from other apps' do
    it 'creates user when received :create notification' do
      user = build(:user)
      data = user.as_json(only: %i[name email]).merge(id: 999)
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: :create })
      expect { payload.process! }.to change(described_class, :count)
    end

    it 'updates user when received :update notification' do
      user = create(:user)
      name = 'new name'
      data = user.as_json(only: %i[id email]).merge(name: name)
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: :update })
      payload.process!
      expect(user.reload.name).to eq(name)
    end

    it 'destroys user when received :destroy notification' do
      user = create(:user)
      data = user.as_json(only: %i[id])
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: :destroy })
      payload.process!
      expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  
    
    it 'receive custom model notification' do
      user = create(:user)  
      data = { id: user.id, custom_data: {} }
      custom_action = :say_hello
      expect_any_instance_of(User).to receive(custom_action).with(data)
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: custom_action })
      payload.process!
    end

    it 'receive class notification' do
      data = { msg: 'hello' }
      action = :greeting
      expect(User).to receive(action).with(data)
      # Do not forget to include `mode: :klass` for class notifications
      payload = PubSubModelSync::Payload.new(data, { klass: 'User', action: action, mode: :klass })
      payload.process!
    end
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
    * skip self notifications
    * continue the sync from the last synced notification when service was restarted.
- `.default_topic_name = "my_topic"`: (String|Array<String>, optional(default first topic from `topic_name`))     
    Topic name used as the default topic if not defined in the payload when publishing a notification
- ```.debug = true```
    (true/false*) => show advanced log messages
- ```.logger = Rails.logger```
    (Logger) => define custom logger
- ```.on_before_processing = ->(payload, {subscriber:}) { puts payload }```
    (Proc) => called before processing a received notification (:cancel can be returned to skip processing)
- ```.on_success_processing = ->(payload, {subscriber:}) { puts payload }```
    (Proc) => called when a notification was successfully processed
- ```.on_error_processing = ->(exception, {payload:, subscriber:}) { payload.delay(...).process! }```
    (Proc) => called when a notification has failed when processing (delayed_job or similar can be used for retrying)
- ```.on_before_publish = ->(payload) { puts payload }```
    (Proc) => called before publishing a notification (:cancel can be returned to skip publishing)
- ```.on_after_publish = ->(payload) { puts payload }```
    (Proc) => called after publishing a notification
- ```.on_error_publish = ->(exception, {payload:}) { payload.delay(...).retry_publish! }```
    (Proc) => called when failed publishing a notification (delayed_job or similar can be used for retrying)
- ```.skip_cache = false```
  (true/false*) => Allow to skip payload optimization (cache settings)
- ```.sync_mode = true```
    (true/false*) => If `true`, the messages are delivered synchronously, else, they are delivered asynchronously (Currently, only GooglePubsub supports it). Also it can be enabled via env var: `PUBSUB_MODEL_SYNC_MODE=true`
- ```.transactions_max_buffer = 1``` (Integer, default 1) Controls the maximum quantity of notifications to be enqueued to the transaction-buffer before delivering them and thus adds the ability to rollback notifications if the transaction fails.        
    Once this quantity of notifications is reached, then all notifications of the current transaction will immediately be delivered (can be customized per transaction).    
    Note: There is no way to rollback delivered notifications if current transaction fails later.      
    Note2: Only notifications from the buffer can be rollbacked if the current transaction has failed.     

## **TODO**
- add the ability to raise SKIP_ACKNOWLEDGE to auto retry by PubSub
- Auto publish update only if payload has changed (see ways to compare previous payload vs new payload)
- Improve transactions to exclude similar notifications by klass and action. Sample:
    ```PubSubModelSync::MessagePublisher.transaction(key, { same_keys: :use_last_as_first|:use_last|:use_first_as_last|:keep*, same_data: :use_last_as_first*|:use_last|:use_first_as_last|:keep })```
- Add DB table to use as a shield to prevent publishing similar notifications and publish partial notifications (similar idea when processing notif)
- Last notification is not being delivered immediately in google pubsub (maybe force with timeout 10secs and service.deliver_messages)
- Update folder structure
- Services support to deliver multiple payloads from transactions
- Fix deprecation warnings: pub_sub_model_sync/service_google.rb:39: warning: Splitting the last argument into positional and keyword parameters is deprecated
- Add if/unless to ps_after_action
- Add subscription liveness checker using thread without db connection to check periodically pending notifications from google pubsub
- Unify .stop() and 'Listener stopped' 
- TODO: Publish new version 1.2.1 (improve logs)
- Enable `async` mode for rabbitMQ and Kafka

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
      PubSubRecovery.perform_async(data[:payload].to_h, :retry_publish!)
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