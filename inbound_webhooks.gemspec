require_relative "lib/inbound_webhooks/version"

Gem::Specification.new do |spec|
  spec.name = "inbound_webhooks"
  spec.version = InboundWebhooks::VERSION
  spec.authors = ["Adam Akhtar"]
  spec.email = ["adamsubscribe@googlemail.com"]
  spec.homepage = "https://github.com/adamakhtar/inbound_webhooks"
  spec.summary = "Rails engine for accepting and processing inbound webhooks"
  spec.description = "A mountable Rails engine that handles inbound webhook reception, authentication, storage, and asynchronous processing with configurable retry logic."
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "pagy", "~> 9.0"
end
