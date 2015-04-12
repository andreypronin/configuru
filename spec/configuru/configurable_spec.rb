require 'spec_helper'

describe Configuru::Configurable do
  before(:each) do
    module TestConfigurableModule
      include Configuru::Configurable
      provide_configuration
      def_config_param :test1
    end
    module TestConfigurableModuleBase
      include Configuru::Configurable
      provide_configuration :base
      def_config_param :test1
    end
    module TestConfigurableModuleInst
      include Configuru::Configurable
      provide_configuration :instances
      def_config_param :test1
    end

    class TestConfigurableClass
      include Configuru::Configurable
      provide_configuration
      def_config_param :test1
    end
    class TestConfigurableClassBase
      include Configuru::Configurable
      provide_configuration :base
      def_config_param :test1
    end
    class TestConfigurableClassInst
      include Configuru::Configurable
      provide_configuration :instances
      def_config_param :test1
    end
  end

  it 'works for modules at base-level' do
    expect{TestConfigurableModuleBase.configure(test1: "1")}.not_to raise_error
    expect(TestConfigurableModuleBase.configuration.test1).to eq "1"
  end
  it 'does not work for modules at instance-level' do
    expect{TestConfigurableModuleInst.configure(test1: "1")}.to raise_error
  end

  it 'works for classes at base-level' do
    expect{TestConfigurableClassBase.configure(test1: "1")}.not_to raise_error
    expect(TestConfigurableClassBase.configuration.test1).to eq "1"
  end
  it 'does not work for classes at instance-level' do
    expect{TestConfigurableClassInst.configure(test1: "1")}.to raise_error
  end

  it 'works for class instances at instance-level' do
    subject = TestConfigurableClassInst.new
    expect{subject.configure(test1: "1")}.not_to raise_error
    expect(subject.configuration.test1).to eq "1"
  end
  it 'does not work for class instances at base-level' do
    subject = TestConfigurableClassBase.new
    expect{subject.configure(test1: "1")}.to raise_error
  end

  it 'provides a separate configuration for each instance and class' do
    subject1 = TestConfigurableClass.new
    subject2 = TestConfigurableClass.new

    expect{TestConfigurableClass.configure(test1: "0")}.not_to raise_error
    expect{subject1.configure(test1: "1")}.not_to raise_error
    expect{subject2.configure(test1: "2")}.not_to raise_error

    expect(TestConfigurableClass.configuration.test1).to eq "0"
    expect(subject1.configuration.test1).to eq "1"
    expect(subject2.configuration.test1).to eq "2"
  end
end
