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

      def param(name, options={})
        param_names << name.to_sym

        inst_var = "@#{name}"
        define_method(name) do
          if !instance_variable_defined?(inst_var) && options.key?(:default)
            instance_variable_set inst_var, options[:default]
          end
          instance_variable_get inst_var
        end

        define_method("#{name}=") do |value|
          if options[:lockable] && locked?
            fail ArgumentError.new("'#{name}' cannot be set at this time")
          end
          if options[:not_nil] && value.nil?
            fail ArgumentError.new("'#{name}' cannot be nil")
          end
          if options[:not_empty] && (value.nil? || value.empty?)
            fail ArgumentError.new("'#{name}' cannot be empty")
          end
          if options.key?(:must_be) && !Array(options[:must_be]).include?(value.class)
            valid_class = false
            Array(options[:must_be]).each do |cname|
              valid_class = true if value.is_a?(cname)
            end
            fail ArgumentError.new("Wrong class (#{value.class}) for '#{name}' value") unless valid_class
          end
          if options.key?(:must_respond_to)
            Array(options[:must_respond_to]).each do |mname|
              fail ArgumentError.new("'#{name}' must respond to '#{mname}'") unless value.respond_to?(mname)
            end
          end
          value = Hash(value) if options[:make_hash]
          value = Array(value) if options[:make_array]
          value = String(value) if options[:make_string]
          value = value.to_i if options[:make_int]
          value = value.to_f if options[:make_float]
          value = !!value if options[:make_bool]
          if options.key?(:max) && (value > options[:max])
            fail ArgumentError.new("'#{name}' must be not more than #{options[:max]}")
          end
          if options.key?(:min) && (value < options[:min])
            fail ArgumentError.new("'#{name}' must be not less than #{options[:min]}")
          end
          if options.key?(:in) && !options[:in].include?(value)
            fail ArgumentError.new("'#{name}' is out of range")
          end
          if options.key?(:convert)
            if options[:convert].is_a? Symbol
              value = @__parent_object.send options[:convert], value
            else
              value = options[:convert].call(value)
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

    def locked?
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
      Hash(options).each_pair do |name, value|
        if name.to_sym == :options_source
          self.options_source = value
        else
          send("#{name}=", value)
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
                      File.open(value, 'r') { |f| output = YAML.load(f) }
                      output
                    else
                      fail ArgumentError.new("Wrong argument class for options_source: #{value.class}")
                      end
      if sub_options.is_a? Array
        sub_options.each { |elem| self.options_source = elem }
      else
        configure(sub_options)
      end
    end
  end
end
