# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pub_sub_model_sync/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 2.4'
  spec.name          = 'pub_sub_model_sync'
  spec.version       = PubSubModelSync::VERSION
  spec.authors       = ['Owen']
  spec.email         = ['owenperedo@gmail.com']

  spec.summary       = 'Permit to sync models between apps through pub/sub'
  spec.description   = 'Permit to sync models between apps through pub/sub'
  spec.homepage      = 'https://github.com/owen2345/pub_sub_model_sync'
  spec.license       = 'MIT'

  # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0")
                     .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rails'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
end
