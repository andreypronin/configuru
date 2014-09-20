# Configuru

Provides convenient interface for managing configuration parameters for modules, classes and instances.
Requires Ruby version >= 2.1.

[![Build Status](https://travis-ci.org/moonfly/configuru.svg?branch=master)](https://travis-ci.org/moonfly/configuru)
[![Coverage Status](https://img.shields.io/coveralls/moonfly/configuru.svg)](https://coveralls.io/r/moonfly/configuru?branch=master)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'configuru'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install configuru

## Usage

The typical usage scenario is provided below:

```ruby
require 'configuru'

class MyClass
  include Configuru::Configurable
  provide_configuration
  
  def_config_param :secret_key, make_string: true, default: (ENV['SECRET_KEY_'] || '???')
  def_config_param :color, default: :green, 
                   convert: ->(val) { raise "Huh?" unless [:red,:green].include?(val); val }
  def_config_param :percentage, make_float:true, min:0, max:100, default:100
  
  def initialize(options,&block)
    configure(options,&block)
    configuration.lock
  end
end

my_inst = MyClass.new do |config|
  config.secret_key = "VERY-SECR-ETKY"
  config.color = :red
  config.options_source = "/my/path/to/file/with/options.yml"
end

my_inst.configuration.color       #=> :red
my_inst.configuration.secret_key  #=> "VERY-SECR-ETKY"
my_inst.configuration.percentage  #=> 100
```



## Versioning

Semantic versioning (http://semver.org/spec/v2.0.0.html) is used. 

For a version number MAJOR.MINOR.PATCH, unless MAJOR is 0:

1. MAJOR version is incremented when incompatible API changes are made,
2. MINOR version is incremented when functionality is added in a backwards-compatible manner, 
3. PATCH version is incremented when backwards-compatible bug fixes are made.

Major version "zero" (0.y.z) is for initial development. Anything may change at any time. 
The public API should not be considered stable. 

## Dependencies

Requires Ruby version >= 2.1

## Contributing

1. Fork it ( https://github.com/[my-github-username]/configuru/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
