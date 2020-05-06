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
    PubSubModelSync::Config.project = 'project-id'
    PubSubModelSync::Config.credentials = 'path-to-the-config'
    PubSubModelSync::Config.topic_name = 'sample-topic'
    PubSubModelSync::Config.subscription_name = 'p1-subscriber'
    ```
    See details here:
    https://github.com/googleapis/google-cloud-ruby/tree/master/google-cloud-pubsub

- configuration for RabbitMq (You need rabbitmq installed)
    ```ruby
    PubSubModelSync::Config.service_name = :rabbitmq
    PubSubModelSync::Config.bunny_connection = 'amqp://guest:guest@localhost'
    PubSubModelSync::Config.queue_name = ''
    PubSubModelSync::Config.topic_name = 'sample-topic'
    ```
    See details here: https://github.com/ruby-amqp/bunny

- configuration for Apache Kafka (You need kafka installed)
    ```ruby
    PubSubModelSync::Config.service_name = :kafka
    PubSubModelSync::Config.kafka_connection = [["kafka1:9092", "localhost:2121"], logger: Rails.logger]
    PubSubModelSync::Config.topic_name = 'sample-topic'
    ```
    See details here: https://github.com/zendesk/ruby-kafka    

- Add publishers/subscribers to your models (See examples below)

- Start subscribers to listen for publishers (Only in the app that has subscribers)
    ```ruby
    rake pub_sub_model_sync:start
    ```
    Note: Publishers do not need todo this

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
  
  # def self.ps_find_model(data, settings)
  #   where(email: data[:email], ...).first_or_initialize 
  # end
end
```

Note: Be careful with collision of names
```
class User
    # ps_publish %i[name_data:name name:key] # key will be replaced with name_data 
    ps_publish %i[name_data:name key_data:key] # use alias to avoid collision
    
    def key_data
      name
    end
end
``` 

## API
### Subscribers
- Permit to configure class level listeners
  ```ps_class_subscribe(action_name, from_action: nil, from_klass: nil)```
  * from_action: (Optional) Source method name
  * from_klass: (Optional) Source class name
  
- Permit to configure instance level listeners (CRUD)
  ```ps_subscribe(attrs, from_klass: nil, actions: nil, id: nil)```
  * attrs: (Array/Required) Array of all attributes to be synced
  * from_klass: (String/Optional) Source class name (Instead of the model class name, will use this value) 
  * actions: (Array/Optional, default: create/update/destroy) permit to customize action names
  * id: (Sym|Array/Optional, default: id) Attr identifier(s) to find the corresponding model

- Permit to configure a custom model finder
  ```ps_find_model(data, settings)```
  * data: (Hash) Data received from sync
  * settings: (Hash(:klass, :action)) Class and action name from sync
  Must return an existent or a new model object

- Get crud subscription configured for the class   
  ```User.ps_subscriber(action_name)```  
  * action_name (default :create, :sym): can be :create, :update, :destroy

- Inspect all configured listeners
  ```PubSubModelSync::Config.listeners```    

### Publishers
- Permit to configure crud publishers
  ```ps_publish(attrs, actions: nil, as_klass: nil)```
  * attrs: (Array/Required) Array of attributes to be published
  * actions: (Array/Optional, default: create/update/destroy) permit to customize action names
  * as_klass: (String/Optional) Output class name (Instead of the model class name, will use this value)

- Permit to cancel sync called after create/update/destroy (Before initializing sync service)
  ```model.ps_skip_callback?(action)```    
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
      
- Publish a class level notification (Same as above: on demand call)    
  ```PubSubModelSync::MessagePublisher.publish_data(Klass_name, data, action_name)```  
  * klass_name: (required, Class) same class name as defined in ps_class_subscribe(...)
  * data: (required, :hash) message value to deliver    
  * action_name: (required, :sim) same action name as defined in ps_class_subscribe(...)
  
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
      action = :create
      data = { name: 'name', id: 999 }
      publisher = PubSubModelSync::MessageProcessor.new(data, 'User', action)
      publisher.process
      expect(User.where(id: data[:id]).any?).to be_truth
    end
      
    it 'receive class message' do
      action = :greeting
      data = { msg: 'hello' }
      publisher = PubSubModelSync::MessageProcessor.new(data, 'User', action)
      publisher.process
      expect(User).to receive(action)
    end
  
    # Publisher
    it 'publish model action' do
      publisher = PubSubModelSync::MessagePublisher  
      data = { name: 'hello'}
      action = :create
      User.ps_class_publish(data, action: action)
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/pub_sub_model_sync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PubSubModelSync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pub_sub_model_sync/blob/master/CODE_OF_CONDUCT.md).
