# PubSubModelSync
Permit to sync models between rails apps through google (Proximately RabbitMQ) pub/sub service. 
Note: This gem is based on [MultipleMan](https://github.com/influitive/multiple_man) which for now looks unmaintained.

# Features
- Sync CRUD operation between Rails apps. So, all changes made on App1, will be reflected on App2.
    Example: If User is created on App1, this user will be created on App2 too with the accepted attributes.
- Ability to make class level communication 
    Example: If User from App1 wants to generate_email, this can be listened on App2 to make corresponding actions

## Installation
Add this line to your application's Gemfile:
```ruby
gem 'pub_sub_model_sync'
```
And then execute: $ bundle install


## Usage

- Configure pub/sub service (Google pub/sub)
    ```ruby
        # initializers/pub_sub_config.rb
        PubSubModelSync::Config.project = ''
        PubSubModelSync::Config.credentials = ''
        PubSubModelSync::Config.topic_name = ''
        PubSubModelSync::Config.subscription_name = ''
    ```
    See details here:
    https://github.com/googleapis/google-cloud-ruby/tree/master/google-cloud-pubsub

- Add publishers/subscribers to your models (See examples below)

- Start listening for publishers (Only if the app has subscribers)
    ```ruby
    rake pub_sub_model_sync:start
    ```

## Examples
```ruby
# App 1
# attributes: name email age 
class User < ActiveRecord::Base
  include PubSubModelSync::PublisherConcern
  ps_msync_publish(%i[name email])
end

# App 2
class User < ActiveRecord::Base
  include PubSubModelSync::SubscriberConcern
  ps_msync_subscribe(%i[name])
  ps_msync_class_subscribe(:greeting)

  def self.greeting(data)
    puts 'Class message called'
  end
end

# Samples
User.create(name: 'test user') # Review your App 2 to see the created user (only name will be saved)
User.ps_msync_class_publish({ msg: 'Hello' }, action: :greeting) # User.greeting method (Class method) will be called in App2
```

## Advanced Example
```ruby
# App 1
class User < ActiveRecord::Base
  self.table_name = 'publisher_users'
  include PubSubModelSync::PublisherConcern
  ps_msync_publish(%i[name], actions: %i[update], as_klass: 'Client', id: :client_id)
  
  def ps_msync_skip_for?(_action)
    false # here logic with action to skip push message
  end
end

# App 2
class User < ActiveRecord::Base
  self.table_name = 'subscriber_users'
  include PubSubModelSync::SubscriberConcern
  ps_msync_subscribe(%i[name], actions: %i[update], as_klass: 'Client', id: :custom_id)
  ps_msync_class_subscribe(:greeting, as_action: :custom_greeting, as_klass: 'CustomUser')
  
  def self.greeting(data)
    puts 'Class message called through custom_greeting'
  end
end
```

## Testing
- Rspec:
    ```ruby
      # mock google service
      # rails_helper.rb
      require 'pub_sub_model_sync/mock_google_service'
      config.before(:each) do
        pub_sub_mock = PubSubModelSync::MockGoogleService.new
        allow(Google::Cloud::Pubsub).to receive(:new).and_return(pub_sub_mock)
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
      User.ps_msync_class_publish(data, action: action)
      user = User.create(name: 'name', email: 'email')
      expect_any_instance_of(publisher).to receive(:publish_model).with(user, :create, anything)
    end
       
    it 'publish class message' do
      publisher = PubSubModelSync::Publisher  
      data = {msg: 'hello'}
      action = :greeting
      User.ps_msync_class_publish(data, action: action)
      expect_any_instance_of(publisher).to receive(:publish_data).with('User', data, action)
    end
    ```
    
    There are two special methods to extract configured crud settings (attrs, id, ...):
    
    Subscribers: ```User.ps_msync_subscriber_settings```
    
    Publishers: ```User.ps_msync_publisher_settings```
    
    Note: Inspect all configured listeners with: 
    ``` PubSubModelSync::Config.listeners ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pub_sub_model_sync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PubSubModelSync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pub_sub_model_sync/blob/master/CODE_OF_CONDUCT.md).
