Gem::Specification.new do |s|
  s.name        = 'cucumber-ctrf'
  s.version     = '0.0.1'
  s.required_ruby_version = '>= 3.0'
  s.summary     = 'Cucumber formatter to output test results in CTRF (https://www.ctrf.io/) JSON format.'
  s.description = 'A custom Cucumber formatter that supports outputting of test results in CTRF (https://www.ctrf.io/) JSON format, including support for flaky tests.'
  s.authors     = ['James Meneghello', 'DUSC']
  s.email       = 'james@dusc.dev'
  s.homepage    = 'https://github.com/dusc-dev/cucumber-ctrf'
  s.license = 'MIT'

  s.add_runtime_dependency 'cucumber', '> 8'
  s.add_runtime_dependency 'cucumber-messages', '< 25', '> 19'

  s.add_development_dependency 'cucumber', '> 8'
  s.add_development_dependency 'cucumber-messages', '< 25', '> 19'
  s.add_development_dependency 'rake', '~> 13.2'
  s.add_development_dependency 'rspec', '~> 3.13'
  s.add_development_dependency 'rspec-json_matchers'
  s.add_development_dependency 'rubocop', '~> 1.61.0'
  s.add_development_dependency 'rubocop-rake', '~> 0.6.0'
  s.add_development_dependency 'rubocop-rspec', '~> 2.25.0'

  s.files = Dir['README.md', 'LICENSE', 'lib/cucumber-ctrf.rb']
  s.require_path = 'lib'
  s.metadata['rubygems_mfa_required'] = 'true'
end
