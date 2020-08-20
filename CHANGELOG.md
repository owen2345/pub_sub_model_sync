# Change Log

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