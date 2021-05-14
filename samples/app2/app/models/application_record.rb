class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  private

  def log(msg)
    puts "App2:========#{msg}"
  end
end
