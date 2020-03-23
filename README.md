# PubSubModelSync
Permit to sync models data and make calls between rails apps using google or rabbitmq pub/sub service. 

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
  ps_publish(%i[name email])
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
User.ps_class_publish({ msg: 'Hello' }, action: :greeting) # User.greeting method (Class method) will be called in App2
```

## Advanced Example
```ruby
# App 1 (Publisher)
class User < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_publish(%i[name:full_name email], actions: %i[update], as_klass: 'Client', id: :client_id)
  
  def ps_skip_for?(_action)
    false # here logic with action to skip push message
  end
end

# App 2 (Subscriber)
class User < ActiveRecord::Base
  self.table_name = 'subscriber_users'
  include PubSubModelSync::SubscriberConcern
  ps_subscribe(%i[name], actions: %i[update], as_klass: 'Client', id: :custom_id)
  ps_class_subscribe(:greeting, as_action: :custom_greeting, as_klass: 'CustomUser')
  
  def self.greeting(data)
    puts 'Class message called through custom_greeting'
  end
end
```

## Testing with RSpec
- Config: (spec/rails_helper.rb)
    ```ruby
      
      # when using google service
      require 'pub_sub_model_sync/mock_google_service'
      config.before(:each) do
        pub_sub_mock = PubSubModelSync::MockGoogleService.new
        allow(Google::Cloud::Pubsub).to receive(:new).and_return(pub_sub_mock)
      end
      
      # when using rabbitmq service
      require 'pub_sub_model_sync/mock_rabbit_service' 
      config.before(:each) do
        bunny_mock = PubSubModelSync::MockRabbitService.new
        allow(Bunny).to receive(:new).and_return(bunny_mock)
      end
  
    ```
- Examples:
    ```ruby
    # Subscriber
    it 'receive model message' do
      action = :create
      data = { name: 'name' }
      user_id = 999
      attrs = PubSubModelSync::Publisher.build_attrs('User', action, user_id)
      publisher = PubSubModelSync::MessageProcessor.new(data, 'User', action, id: user_id)
      publisher.process
      expect(User.where(id: user_id).any?).to be_truth
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
      publisher = PubSubModelSync::Publisher  
      data = { name: 'hello'}
      action = :create
      User.ps_class_publish(data, action: action)
      user = User.create(name: 'name', email: 'email')
      expect_any_instance_of(publisher).to receive(:publish_model).with(user, :create, anything)
    end
       
    it 'publish class message' do
      publisher = PubSubModelSync::Publisher  
      data = {msg: 'hello'}
      action = :greeting
      User.ps_class_publish(data, action: action)
      expect_any_instance_of(publisher).to receive(:publish_data).with('User', data, action)
    end
    ```
    
    There are two special methods to extract crud configuration settings (attrs, id, ...):
    
    Subscribers: ```User.ps_subscriber```
    
    Publishers: ```User.ps_publisher```
    
    Note: Inspect all configured listeners with: 
    ``` PubSubModelSync::Config.listeners ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/pub_sub_model_sync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PubSubModelSync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pub_sub_model_sync/blob/master/CODE_OF_CONDUCT.md).
