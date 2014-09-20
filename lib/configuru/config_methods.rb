require 'yaml'

module Configuru
  module ConfigMethods
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods
    module ClassMethods
      def param_names
        @param_names ||= []
      end
      def param(name,options={})
        param_names << name.to_sym
      
        inst_var = "@#{name.to_s}"
        define_method(name) do
          if !instance_variable_defined?(inst_var) && options.has_key?(:default)
            instance_variable_set inst_var, options[:default]
          end
          instance_variable_get inst_var
        end

        define_method("#{name.to_s}=") do |value|
          if options[:lockable] && is_locked
            raise ArgumentError.new("'#{name.to_s}' cannot be set at this time")
          end
          if options[:not_nil] && value.nil?
            raise ArgumentError.new("'#{name.to_s}' cannot be nil")
          end
          if options[:not_empty] && (value.nil? || value.empty?)
            raise ArgumentError.new("'#{name.to_s}' cannot be empty")
          end
          if options.has_key?(:must_be) && !Array(options[:must_be]).include?(value.class)
            valid_class = false
            Array(options[:must_be]).each do |cname|
              valid_class = true if value.is_a?(cname)
            end
            raise ArgumentError.new("Wrong class (#{value.class}) for '#{name.to_s}' value") unless valid_class
          end
          if options.has_key?(:must_respond_to)
            Array(options[:must_respond_to]).each do |mname|
              raise ArgumentError.new("'#{name.to_s}' must respond to '#{mname}'") unless value.respond_to?(mname)
            end
          end
          value = Hash(value) if options[:make_hash]
          value = Array(value) if options[:make_array]
          value = String(value) if options[:make_string]
          value = value.to_i if options[:make_int]
          value = value.to_f if options[:make_float]
          value = !!value if options[:make_bool]
          if options.has_key?(:max) && (value > options[:max])
            raise ArgumentError.new("'#{name.to_s}' must be not more than #{options[:max]}")
          end
          if options.has_key?(:min) && (value < options[:min])
            raise ArgumentError.new("'#{name.to_s}' must be not less than #{options[:min]}")
          end
          if options.has_key?(:in) && !options[:in].include?(value)
            raise ArgumentError.new("'#{name.to_s}' is out of range")
          end
          if options.has_key?(:convert)
            if options[:convert].is_a? Symbol
              value = @__parent_object.send options[:convert], value
            else
              value = options[:convert].call( value )
            end
          end

          instance_variable_set inst_var, value
        end
        name
      end
    end

    # Instance methods
    def lock(flag=true)
      @locked = flag
    end
    def is_locked
      @locked = false unless instance_variable_defined?(:@locked)
      @locked
    end
    def param_names
      self.class.param_names
    end
    def set_parent_object(object)
      @__parent_object = object
    end
    
    def configure(options={})
      Hash(options).each_pair do |name,value|
        if name.to_sym == :options_source
          self.options_source = value
        else
          send("#{name.to_s}=",value)
        end
      end
      yield self if block_given?
      self
    end
    def options_source=(value)
      sub_options = case value
        when Hash, Array then value
        when IO, StringIO, Tempfile then 
          YAML.load(value)
        when String, Pathname
          output = {}
          File.open(value,"r") { |f| output = YAML.load(f) }
          output
        else
          raise ArgumentError.new("Wrong argument class for options_source: #{value.class}")
      end
      if sub_options.is_a? Array
        sub_options.each { |elem| self.options_source=elem }
      else
        configure(sub_options)
      end
    end
    

  end
end
