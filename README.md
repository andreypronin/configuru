# Configuru

Provides convenient interface for managing configuration parameters for modules, classes and instances.
Requires Ruby version >= 2.1.

[![Build Status](https://travis-ci.org/moonfly/configuru.svg?branch=master)](https://travis-ci.org/moonfly/configuru)
[![Coverage Status](https://img.shields.io/coveralls/moonfly/configuru.svg)](https://coveralls.io/r/moonfly/configuru?branch=master)

## Installation

To add to an application, add this line to your application's Gemfile:

```ruby
gem 'configuru'
```

To add to a gem, add the following line to your gemspec file:

```ruby
Gem::Specification.new do |spec|
  ...  
  spec.add_dependency 'configuru'
  ...
end
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install configuru

## Usage

### Overview

This gem allows to add convenient configuration API to modules, classes and instances in your gem or application. It is intentially designed to minimize "behind-the-scenes auto-magic" and yet keep it easy to use and the calling code concise.

Here is an example of how Configuru can be used to provide configuration for `MyClass`:

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

### Making your objects configurable

To make your class or module configurable you need to do two things: 

1. `include Configuru::Configurable` 
2. then call `provide_configuration` with an optional parameter as defined below:

```ruby
  provide_configuration :base       # Using one of these three options will add configuration API
  provide_configuration :class      # only to your class/module. The individual instances of that class
  provide_configuration :module     # will not be given any configuration API.
  
  provide_configuration :instances  # Using one of these two options will add configuration API to
  provide_configuration :instance   # individual instances of the class, but not for the class itself.
  
  provide_configuration             # Using these options will add configuration API both to the class
  provide_configuration :all        # and to the instances of that class
```

### Configuration API

#### Defining possible configuration parameters
The class module, inside which you called `provide_configuration`, will get a `def_config_param` method for defining possible configuration parameters. This method takes a parameter name and various options for it:

* Provide default value for the configuration parameter. The value is evaluated at the time `def_config_param` is called. The checks and conversions specified for the parameter (see below) are *not* applied to the default value.
  
  ```ruby
  def_config_param :some_name, default: ""
  ```
  
* Prevent the parameter from changing once configuration is locked (see section "Locking configuration" below)

  ```ruby
  def_config_param :some_name, lockable: true 
  ```
  
* When setting, check that the value is not nil or not empty. "Not empty" means that both `.nil?` and `.empty?` for it return `false`. Raise ArgumentError exception if the check fails.

  ```ruby
  def_config_param :some_name, not_nil: true      # Check for "not nil"
  def_config_param :some_name, not_empty: true    # Check for "not empty"
  ```

* When setting, check that the value is of a certain type (`is_a?` returns true). If an array of types is passed, the value must be of *any* of the types from that array. Raise ArgumentError exception if the check fails.

  ```ruby
  def_config_param :some_name, must_be: String
  def_config_param :some_name, must_be: [IO,File,StringIO]
  ```

* When setting, perform duck-type-checking. Check that the value resonds to a certain method. If an array of method names is passed, the value must respond to *all* specified methods. Raise ArgumentError exception if the check fails.

  ```ruby
  def_config_param :some_name, must_respond_to: :read
  def_config_param :some_name, must_respond_to: [:read,:seek]
  ```
  
* When setting, convert the value to a specific type

  ```ruby
  def_config_param :some_name, make_hash: true    # Hash(value)
  def_config_param :some_name, make_array: true   # Array(value)
  def_config_param :some_name, make_string: true  # String(value)
  def_config_param :some_name, make_int: true     # value.to_i
  def_config_param :some_name, make_float: true   # value.to_f
  def_config_param :some_name, make_bool: true    # !!value
  ```
  
* When setting, check that the value is within the specified boundaries. Raise ArgumentError exception if the check fails.

  ```ruby
  def_config_param :some_name, max: 10          # Raise exception if trying to set value > 10
  def_config_param :some_name, min: 0.01        # Raise exception if trying to set value < 0.01
  def_config_param :some_name, in: ('a'..'z')   # Raise exception unless ('a'..'z').include?(value)
  ```

* When setting, perform call the conversion method. The original value is passed as the only parameter. The method should either return the converted value, or raise some exception. If a symbol is passed, the method with that name is called on the object under configuration.

  ```ruby
  class MyClass {
    def_config_param :some_name1, convert: :some_conversion  
    def_config_param :some_name2, convert: ->(x) { x.abs }
  }
  
  my_inst = MyClass.new
  my_inst.configure( some_name1: "abc" )    # will call my_inst.some_conversion("abc") and assign the result to some_name1 parameter
  ```

A single parameter may have several checks and conversions associated with it. If several are defined, they will be applied in the order they are defined in the list above.
For example, if the parameter is defined as

```ruby
class MyClass {
  include Configuru::Configurable
  provide_configuration :class

  def_config_param :myparam, lockable: true, not_nil: true, make_int: true, in: (-3..3), convert: ->(x) { x.abs }
}
```

If you call `MyClass.configure( myparam: "-1" )` then Configuru will:
1. Check that `MyClass.configuration` is not locked yet (and raise exception if it is).
2. Check that the provided value is not nil (and raise exception if it is). 
3. Convert the value to int (and raise exception if it can't do that).
4. Check that it is included in the -3..3 range (and raise exception if it is not).
5. Convert it: get the absolute value as specifed in the provided lambda.
6. Assign the resulting value to the `myparam` configuration parameter.

In this case (unless the configuration was locked) the parameter will eventually be set to 1.


#### Working with configuration parameters through configuration object
The object that you made configurable using `provide_configuration` will get a `configuration` method that returns its configuration object. The configuration object has all the parameters defined through `def_config_param` as its attributes and allows reading and writing them. The same parameter can be set several times, and each later value replaces the one set earlier.

```ruby
require 'configuru'

class MyClass
  include Configuru::Configurable
  provide_configuration :instance
  
  def_config_param :secret_key, make_string: true, default: (ENV['SECRET_KEY_'] || '???')
  def_config_param :color, default: :green, 
                   convert: ->(val) { raise "Huh?" unless [:red,:green].include?(val); val }
  def_config_param :percentage, make_float:true, min:0, max:100, default:100
end  


my_inst = MyClass.new

my_inst.configuration.secret_key = "VERY-SECR-ETKY"
my_inst.configuration.color = :red

my_inst.configuration.color       #=> :red
my_inst.configuration.secret_key  #=> "VERY-SECR-ETKY"
my_inst.configuration.percentage  #=> 100
```

##### Configure method
The object that you made configurable using `provide_configuration` also gets a `configure` convenience method. The method allows you to either provide configuration parameters as a hash or call the provided block with the configuration object.

```ruby
require 'configuru'

class MyClass
  include Configuru::Configurable
  provide_configuration :instance
  
  def_config_param :secret_key, make_string: true, default: (ENV['SECRET_KEY_'] || '???')
  def_config_param :color, default: :green, 
                   convert: ->(val) { raise "Huh?" unless [:red,:green].include?(val); val }
  def_config_param :percentage, make_float:true, min:0, max:100, default:100
end  


my_inst = MyClass.new

# Setting parameters using Hash
my_inst.configure secret_key: "VERY-SECR-ETKY", color: :red

# Setting parameters using the block called on the configuration object
my_inst.configure do |config|
  config.secret_key = "VERY-SECR-ETKY"
  config.color = :red
end
```

It is also possible to use Hash and block in the same call to configure. In this case first the Hash will be precessed, then the block will be called. So, any values set in the block will supersede the values set through Hash.

```ruby
my_inst.configure(color: :red) do |config|
  config.secret_key = "VERY-SECR-ETKY"
end
```

##### Reading configuration from file
The configuration object can also read configuration from a YAML file using `options_source=` call on the configuration object or `options_source` key in the Hash provided to configure. The `options_source=` can be called several times for a configuration object, and the parameters will be loaded from files in the order they are called. The file reading can also be nested:  YAML files themselves may have the `options_source` parameter defined inside. As with direct parameter setting, if a parameter is set several times in multiple files, the latest value replaces all previous values. 

```ruby
require 'configuru'

class MyClass
  include Configuru::Configurable
  provide_configuration :instance
  
  # bunch of def_config_param calls ...
end  

my_inst = MyClass.new

# Directly call on the configuraton object - this will load the parameters from the three
# files in the order they are specified
my_inst.configuration.options_source = "/my/path/to/file/with/options1.yml"
my_inst.configuration.options_source = "/my/path/to/file/with/options2.yml"
my_inst.configure do |config|
  config.options_source = "/my/path/to/file/with/options3.yml"
end

# Or, pass it as a part of Hash to configure
my_inst.configure options_source: "/my/path/to/file/with/options1.yml"
```

Using `options_source` may be combined with directly setting the parameters. And, again, the values provided later overwrite previously provided values for the same parameter.

```ruby
my_inst = MyClass.new do |config|
  config.secret_key = "VERY-SECR-ETKY"
  config.color = :red
  config.options_source = "/my/path/to/file/with/options.yml" # will overwrite color and secret_key if defined in YAML
end
```

##### Locking configuration
The configuration object also has a `lock` method. Calling this method prevents the parameters defined as lockable from further changes. The parameters, for which the `lockable` option was not set, are not affected. Locking is useful if you somehow cache configuration parameters in other parts of your application/gem, and further changes to the parameter will not affect the configuration behavior. 

For example, if one of your parameters is a database name or an AWS access key, once you use this parameter at the beginning of your applicaton to establish connection to the database or get access to your AWS resources, further changes to it won't make your application to reconnect to a different database or start accessing AWS using a different set of credentials. In this case, locking helps to catch configuraton bugs, when the parameter is set or changed too late.

Locking affects all parameters marked as `lockable`. There is no locking at individual parameter level.

If a lockable parameter is accessed after `lock` has been called, `ArgumentError` is raised.

```ruby
require 'configuru'

class MyClass
  include Configuru::Configurable
  provide_configuration :instance
  
  def_config_param :database, lockable: true
end  

my_inst = MyClass.new

my_inst.configuration.database = 'db_production'
my_inst.configuration.lock
my_inst.configuration.database = 'db_staging'     # Raises ArgumentError
```

It is also possible to unlock the parameters after they were locked by calling `lock(false)`. Using the previous example:

```ruby
my_inst.configuration.database = 'db_production'
my_inst.configuration.lock
my_inst.configuration.database = 'db_staging'     # Raises ArgumentError
my_inst.configuration.lock(false)
my_inst.configuration.database = 'db_development' # Works fine
```

Both `lock` and `lock(false)` can be called several times. But there is no counter: after calling `lock` multiple times, a single `lock(false)` would unlock all parameters.

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

## Backlog

The following features may be included in the future versions of this gem, if a need for them is identified.
If you'd like to see one of these features or something else implemented in Configuru, please let the authors know.

* Provide callbacks for when parameters are changed (would allow reconnecting to a DB, for example when a database name is changed)
* Provide a choice for locked parameters: throw an exception or silently ignore, may be with a callback
* Add logging and make it configurable (simplify life for people who want to see the parameter values logged)
* Lock at parameter level (are there any real-life scenarios when that is needed?)
* Dump parameters to Hash/YAML file (allows saving/restoring configuration)
* Add write-once parameters: auto-locking after setting for the 1st time (does anybody need that?)
* Add required parameters, when reqding it w/o setting it first would raise an exception rather than using the default value
* Allow iterating through all parameters/parameter names (useful for alt storage mechanisms - e.g. store in DB)
* Better integration with ENV - automatically add variables as parameters using a defined list of names
* Other formats besides Hash & YAML? - probably not, it's easy to add on top after dumping and/or iterating are implemented
* Use gem-specific exceptions, not ArgumentError for all cases

## Contributing

1. Fork it ( https://github.com/moonfly/configuru/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
