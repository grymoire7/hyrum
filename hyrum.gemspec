# frozen_string_literal: true

# hyrum.gemspec

require_relative 'lib/hyrum/version'

Gem::Specification.new do |gem|
  gem.name          = 'hyrum'
  gem.version       = Hyrum::VERSION
  gem.summary       = 'A simple Ruby gem'
  gem.authors       = ['Tracy Atteberry']
  gem.email         = ['tracy@tracyatteberry.com']
  gem.description   = "A multi-language code generator to cope with Hyrum's law"
  gem.homepage      = 'https://github.com/grymoire7/hyrum'
  gem.licenses      = ['MIT']
  gem.required_ruby_version = '>= 3.1.0'

  gem.metadata['rubygems_mfa_required'] = 'true'
  gem.metadata['homepage_uri'] = gem.homepage
  gem.metadata['source_code_uri'] = gem.homepage
  gem.metadata['changelog_uri'] = "#{gem.homepage}/blob/master/CHANGELOG.md"

  gem.extra_rdoc_files = Dir['README.md', 'CHANGELOG.md', 'LICENSE.txt']
  gem.rdoc_options += [
    '--title', 'Hyrum - Hyrum\'s Law Code Generator',
    '--main', 'README.md',
    '--line-numbers',
    '--inline-source',
    '--quiet'
  ]

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # gem.files = Dir.chdir(__dir__) do
  #   `git ls-files -z`.split("\x0").reject do |f|
  #     (File.expand_path(f) == __FILE__) ||
  #       f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
  #   end
  # end
  gem.files = Dir.glob('lib/**/*') + Dir.glob('bin/**/*')

  gem.bindir = 'exe'
  gem.executables = gem.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  # gem.executables   = ['hyrum']
  gem.require_paths = ['lib']

  # gem.add_dependency 'gen-ai', '~> 0.4'
  gem.add_dependency 'ruby-openai', '~> 7.3'
  gem.add_dependency 'zeitwerk', '~> 2.6'
end
