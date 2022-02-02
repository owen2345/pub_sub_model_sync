# Sample model sync
This is a sample to sync information between rails applications using RabbitMQ

## Installation
* Create manually the required network to share rabbitMQ accross Rails applications (just if not exist):   
  ```docker network create shared_app_services```
  
* Start RabbitMQ server   
  ```cd samples/app1 && docker-compose up pubsub```

* In another tab access to App1 to publish notifications (Wait for step 2)  
  - Access to the application    
    `cd samples/app1`    
  
  - Build docker and enter rails console    
    ```docker-compose run app bash -c "rails db:migrate && rails c"```
  
  - Create a sample user    
    ```ruby
      user = User.create!(name: 'User 1', posts_attributes: [{ title: 'Post 1' }, { title: 'Post 2' }])
    ```
    Note: Check app2 console to see notifications (3 notifications)    
    Note2: Access app2 console to see user and its posts
    
  - Update previous user
    ```ruby
      user.update!(name: 'User 1 changed', posts_attributes: user.posts.map { |post| { id: post.id, title: "#{post.title} changed" } })
    ```
    Note: Check app2 console to see notifications (3 notifications)    
    Note2: Access app2 console to see changes for user and its posts
    
  - Destroy previous user
    ```ruby
      user.destroy!
    ```    

* In another tab access to App2 to listen notifications (Wait for step 2)      
  - Access to the folder
    `cd samples/app2`
  
  - Build docker and start listener (Received notifications will be printed here)       
    ```docker-compose run listener```
  
  - Optional: Open another tab to access application to ensure synced data
    ```docker-compose run listener bash -c "rails c```
    ```ruby
      user = User.last.inspect
      user.posts.inspect
    ```
  
