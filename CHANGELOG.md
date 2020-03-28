# Change Log

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