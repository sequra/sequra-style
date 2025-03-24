lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sequra/style/version"

Gem::Specification.new do |spec|
  spec.name          = "sequra-style"
  spec.version       = Sequra::Style::VERSION
  spec.authors       = ["Sequra engineering"]
  spec.email         = ["rubygems@sequra.es"]

  spec.summary       = "Sequra code style guides and shared config"
  spec.homepage      = "https://github.com/sequra/sequra-style"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rubocop", "~> 1"
  spec.add_dependency "rubocop-performance", "~> 1"
  spec.add_dependency "rubocop-rails", "~> 2"
  spec.add_dependency "rubocop-rspec", "~> 2"
  spec.add_dependency "rubocop-obsession", "~> 0.2"

  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "rake", "~> 13.0.1"
end
