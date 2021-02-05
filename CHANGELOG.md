# Change Log

# 0.5.8.2 (February 05, 2021)
- fix: restore google pubsub topic settings
# 0.5.8.1 (February 05, 2021)
- fix: keep message ordering with google pubsub

# 0.5.8 (January 29, 2021)
- fix: keep message ordering with google pubsub

# 0.5.7.1 (January 26, 2021)
- fix: does not call :on_error_processing when processing a message 

# 0.5.7 (January 13, 2021)
- feat: add method to preload sync listeners

# 0.5.6 (January 12, 2021)
- feat: add payload validation
- feat: add method to rebuild payload

# 0.5.5 (January 11, 2021)
- feat: google-pub/sub receive messages in the same order they were delivered

# 0.5.4.1 (January 8, 2021)
- fix: google-pub/sub receive messages sequentially and not in parallel (default 5 threads).

# 0.5.4 (January 8, 2021)
- fix: exclude identifiers when syncing model
- feat: callbacks support for future extra params
- feat: make connectors configurable
- feat: add :process! and :process, :publish!, :publish methods to payload
- feat: auto retry 2 times when "could not obtain a database connection within 5.000 seconds..." error occurs

# 0.5.3 (December 30, 2020)
- fix: kafka consume all messages from different apps
- style: use the correct consumer key

# 0.5.2 (December 30, 2020)
- fix: rabbitmq deliver messages to all subscribers
- fix: rabbitmq persist messages to recover after restarting

# 0.5.1.1 (December 29, 2020)
- Hotfix: auto convert class name into string

# 0.5.1 (December 24, 2020)
- feat: rename publisher callbacks to be more understandable
- feat: add callbacks to listen when processing a message (before saving sync)

# 0.5.0.1 (December 22, 2020)
- fix: add missing rabbit mock method

# 0.5.0 (December 22, 2020)
- feat: add :publish! and :process! methods to payloads
- feat: add ability to disable publisher globally
- fix: skip notifications from the same application
- fix: rabbitmq use fanout instead of queue to deliver messages to multiple apps
- refactor: include payload object to carry message info
- feat: include notification events (when publishing and when processing messages)

# 0.4.2.2 (November 29, 2020, deleted cause of typo)
- feat: rabbitMQ skip receiving messages from the same app
- feat: rabbitmq use fanout instead of queue to deliver messages to multiple apps
 
# 0.4.2.1 (August 20, 2020)
- Improve ```ps_subscriber_changed?``` to run validations and check for changes
 
# 0.4.2 (May 12, 2020)
- chore: remove typo

# 0.4.1 (May 12, 2020)
- chore: improve log messages
- feat: do not update model if no changes
- feat: skip publisher after updating if no changes


# 0.4.0 (May 06, 2020)
- rename as_klass to from_klass and as_action to from_action for subscribers
- refactor subscribers to be independent
- refactor message_publisher to use publisher
- rename publisher into message_publisher
- reformat publisher to reuse connector

# 0.3.1 (May 05, 2020)
- improve rabbit service to use sleep instead of block ("Block is not recommended for production")
- improve message ID

# 0.3.0 (April 29, 2020)
- Support for multiple identifiers when syncing
- Add klass.ps_find_model method for a custom model finder

# 0.2.4 (April 28, 2020)
- Delegate .publish to the .publisher for better understanding

# 0.2.3 (April 15, 2020)
- Improve helper names
- feat: perform manual sync with custom settings
- fix for "IO timeout when reading 7 bytes" error (Rabbit)
- style: do not print processed message when failed
- feat: retry delivery message when failed (RabbitMQ)


# 0.2.2 (March 27, 2020)
- fix default value for cattr_accessor in ror < 5.2
- add callbacks when publishing a message

# 0.2.1
- Add on demand model sync method

# 0.2.0
- Add apache kafka support
- Add Service interface for future references
- Improve Services to use a single/common message performer

# 0.1.4
- Add attribute aliases when publishing, ```ps_publish(['name:full_name', 'email'])```
- Ability to retrieve publisher/subscriber crud settings

# 0.1.3
- shorter publisher/subscriber methods: ps_msync_subscribe into ps_subscribe

# 0.1.2
- fix not found pub/sub library (buggy)

# 0.1.1
- Add rabbitmq pub/sub service support
- Reformat to support multiple pub/sub services

# 0.1.0
- Google pub/sub support