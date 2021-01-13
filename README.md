# PubSubModelSync
Permit to sync models data and make calls between rails apps using google or rabbitmq or apache kafka pub/sub service. 

Note: This gem is based on [MultipleMan](https://github.com/influitive/multiple_man) which for now looks unmaintained.

## Features
- Sync CRUD operations between Rails apps. So, all changes made on App1, will be reflected on App2, App3.
    Example: If User is created on App1, this user will be created on App2 too with the accepted attributes.
- Ability to make class level communication
    Example: If User from App1 wants to generate_email, this can be listened on App2, App3, ... to make corresponding actions
- Change pub/sub service at any time

## Installation
Add this line to your application's Gemfile:
```ruby
gem 'pub_sub_model_sync'

gem 'google-cloud-pubsub' # to use google pub/sub service
gem 'bunny' # to use rabbit-mq pub/sub service
gem 'ruby-kafka' # to use apache kafka pub/sub service
```
And then execute: $ bundle install


## Usage

- Configuration for google pub/sub (You need google pub/sub service account)
    ```ruby
    # initializers/pub_sub_config.rb
    PubSubModelSync::Config.service_name = :google 
    PubSubModelSync::Config.project = 'google-project-id'
    PubSubModelSync::Config.credentials = 'path-to-the-config'
    PubSubModelSync::Config.topic_name = 'sample-topic'
    ```
    See details here:
    https://github.com/googleapis/google-cloud-ruby/tree/master/google-cloud-pubsub

- configuration for RabbitMq (You need rabbitmq installed)
    ```ruby
    PubSubModelSync::Config.service_name = :rabbitmq
    PubSubModelSync::Config.bunny_connection = 'amqp://guest:guest@localhost'
    PubSubModelSync::Config.queue_name = 'model-sync'
    PubSubModelSync::Config.topic_name = 'sample-topic'
    ```
    See details here: https://github.com/ruby-amqp/bunny

- configuration for Apache Kafka (You need kafka installed)
    ```ruby
    PubSubModelSync::Config.service_name = :kafka
    PubSubModelSync::Config.kafka_connection = [["kafka1:9092", "localhost:2121"], { logger: Rails.logger }]
    PubSubModelSync::Config.topic_name = 'sample-topic'
    ```
    See details here: https://github.com/zendesk/ruby-kafka    

- Add publishers/subscribers to your models (See examples below)

- Start subscribers to listen for publishers (Only in the app that has subscribers)
    ```ruby
    rake pub_sub_model_sync:start
    ```
    Note: Publishers do not need todo this    
    Note2 (Rails 6+): Due to Zeitwerk, you need to load listeners manually when syncing without mentioned task (like rails console)
    ```ruby 
      # PubSubModelSync::Config.subscribers ==> []
      PubSubModelSync::Runner.preload_listeners
      # PubSubModelSync::Config.subscribers ==> [#<PubSubModelSync::Subscriber:0x000.. @klass="Article", @action=:create..., ....]
    ``` 

- Check the service status with:    
  ```PubSubModelSync::MessagePublisher.publish_data('Test message', {sample_value: 10}, :create)```

## Examples
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
  ps_subscribe(%i[name])
  ps_class_subscribe(:greeting)

  def self.greeting(data)
    puts 'Class message called'
  end
end

# Samples
User.create(name: 'test user', email: 'sample@gmail.com') # Review your App 2 to see the created user (only name will be saved)
User.new(name: 'test user').ps_perform_sync(:create) # similar to above to perform sync on demand

User.ps_class_publish({ msg: 'Hello' }, action: :greeting) # User.greeting method (Class method) will be called in App2
PubSubModelSync::MessagePublisher.publish_data(User, { msg: 'Hello' }, :greeting) # similar to above when not included publisher concern
```

## Advanced Example
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[id:client_id name:full_name email], actions: %i[update], as_klass: 'Client')
  
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
  alias_attribute :full_name, :name
  
  def self.greeting(data)
    puts 'Class message called through custom_greeting'
  end
  
  # def self.ps_find_model(data)
  #   where(email: data[:email], ...).first_or_initialize 
  # end
end
```

Note: Be careful with collision of names
```
  # ps_publish %i[name_data:name name:key] # key will be replaced with name_data 
  ps_publish %i[name_data:name key_data:key] # use alias to avoid collision
``` 

## API
### Subscribers
- Permit to configure class level subscriptions
  ```ps_class_subscribe(action_name, from_action: nil, from_klass: nil)```
  * from_action: (Optional) Source method name
  * from_klass: (Optional) Source class name
  
- Permit to configure instance level subscriptions (CRUD)
  ```ps_subscribe(attrs, from_klass: nil, actions: nil, id: nil)```
  * attrs: (Array/Required) Array of all attributes to be synced
  * from_klass: (String/Optional) Source class name (Instead of the model class name, will use this value) 
  * actions: (Array/Optional, default: create/update/destroy) permit to customize action names
  * id: (Sym|Array/Optional, default: id) Attr identifier(s) to find the corresponding model

- Permit to configure a custom model finder
  ```ps_find_model(data)```
  * data: (Hash) Data received from sync
  Must return an existent or a new model object

- Get crud subscription configured for the class   
  ```User.ps_subscriber(action_name)```  
  * action_name (default :create, :sym): can be :create, :update, :destroy

- Inspect all configured subscribers   
  ```PubSubModelSync::Config.subscribers```    

- Permit to customize the way to detect if the subscribed model was changed (Only for update action).   
  ```.ps_subscriber_changed?(data)```    
  By default: ```model.changed?```

- Permit to perform custom actions before saving sync of the model (:cancel can be returned to skip sync)   
  ```.ps_before_save_sync(payload)```    

### Publishers
- Permit to configure crud publishers
  ```ps_publish(attrs, actions: nil, as_klass: nil)```
  * attrs: (Array/Required) Array of attributes to be published
  * actions: (Array/Optional, default: create/update/destroy) permit to customize action names
  * as_klass: (String/Optional) Output class name (Instead of the model class name, will use this value)

- Permit to cancel sync called after create/update/destroy (Before initializing sync service)
  ```model.ps_skip_callback?(action)```    
  Default: False  
  Note: Return true to cancel sync
  
- Callback called before preparing data for sync (Permit to stop sync)
  ```model.ps_skip_sync?(action)```     
  Note: return true to cancel sync
  
- Callback called before sync (After preparing data)
  ```model.ps_before_sync(action, data_to_deliver)```  
  Note: If the method returns ```:cancel```, the sync will be stopped (message will not be published)

- Callback called after sync
  ```model.ps_after_sync(action, data_delivered)```  

- Perform sync on demand (:create, :update, :destroy):   
  The target model will receive a notification to perform the indicated action  
  ```my_model.ps_perform_sync(action_name, custom_settings = {})```  
  * custom_settings: override default settings defined for action_name ({ attrs: [], as_klass: nil })
    
- Publish a class level notification:     
  ```User.ps_class_publish(data, action: action_name, as_klass: custom_klass_name)```
  Target class ```User.action_name``` will be called when message is received    
  * data: (required, :hash) message value to deliver    
  * action_name: (required, :sim) Action name    
  * as_klass: (optional, :string) Custom class name (Default current model name)
      
- Payload actions  
  ```ruby
    payload = PubSubModelSync::Payload.new({ title: 'hello' }, { action: :greeting, klass: 'User' })
    payload.publish! # publishes notification data. It raises exception if fails and does not call ```:on_error_publishing``` callback
    payload.publish # publishes notification data. On error does not raise exception but calls ```:on_error_publishing``` callback
    payload.process! # process a notification data. It raises exception if fails and does not call ```.on_error_processing``` callback
    payload.publish # process a notification data. It does not raise exception if fails but calls ```.on_error_processing``` callback
  ```
  
- Get crud publisher configured for the class   
  ```User.ps_publisher(action_name)```  
  * action_name (default :create, :sym): can be :create, :update, :destroy
  
## Testing with RSpec
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
       
    it 'publish class message' do
      publisher = PubSubModelSync::MessagePublisher  
      data = {msg: 'hello'}
      action = :greeting
      User.ps_class_publish(data, action: action)
      expect(publisher).to receive(:publish_data).with('User', data, action)
    end
    ```

## Extra configurations
```ruby
config = PubSubModelSync::Config
config.debug = true
```

- ```.subscription_name = 'app-2'```    
    Permit to define a custom consumer identifier (Default: Rails application name)
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
    
## TODO
- Add alias attributes when subscribing (similar to publisher)
- Add flag ```model.ps_processing``` to indicate that the current transaction is being processed by pub/sub
- Auto publish update only if payload has changed
- On delete, payload must only be composed by ids
- Change notifications into messages 

## Q&A
- Error "could not obtain a connection from the pool within 5.000 seconds"    
  This problem occurs because pub/sub dependencies (kafka, google-pubsub, rabbitmq) use many threads to perform notifications where the qty of threads is greater than qty of DB pools ([Google pubsub info](https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-pubsub/lib/google/cloud/pubsub/subscription.rb#L888))     
  To fix the problem, edit config/database.yml and increase the quantity of ```pool: 10```
- Google pubsub: How to process notifications parallely and not sequentially (default 1 thread)?    
  ```ruby  PubSubModelSync::ServiceGoogle::LISTEN_SETTINGS = { threads: { callback: qty_threads } } ```    
  Note: by this way some notifications can be processed before others thus missing relationship errors can appear
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/pub_sub_model_sync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PubSubModelSync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pub_sub_model_sync/blob/master/CODE_OF_CONDUCT.md).
