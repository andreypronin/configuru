require 'spec_helper'

describe Configuru::ConfigMethods do
  before(:each) {
    class TestSubjectClass
      include Configuru::ConfigMethods
    end
    class TestIoSubjectClass
      include Configuru::ConfigMethods
      param :test1
      param :test2
    end
  }
  let(:subject) { TestSubjectClass.new }
  let(:opts_spec) { Hash('test1' => 'something1', :test2 => 'something2') }
  let(:opts_sio) { StringIO.new(opts_spec.to_yaml) }

  it 'includes class methods' do
    expect(TestSubjectClass.methods).to include :param, :param_names
  end
  it 'returns itself from configure (smoke test)' do
    expect(subject.configure).to eq subject
  end
  it 'allows defining parameters' do
    class << subject
      param :test
    end
    expect(subject).to respond_to :test
    expect(subject).to respond_to :test=
  end

  it 'allows settings variables passed as a hash and/or block' do
    class << subject
      param :test1
      param :test2
    end
    subject.configure({ test1: 'something1' }) do |cfg|
      cfg.test2 = 'something2'
    end
    expect(subject.test1).to eq 'something1'
    expect(subject.test2).to eq 'something2'
  end

  it 'keeps track of parameters' do
    expect(TestIoSubjectClass.param_names).to include :test1, :test2
  end

  it 'allows loading options from Hash' do
    class << subject
      param :test1
      param :test2
    end
    subject.options_source = opts_spec
    expect(subject.test1).to eq 'something1'
    expect(subject.test2).to eq 'something2'
  end

  it 'allows loading options from StringIO' do
    class << subject
      param :test1
      param :test2
    end
    subject.options_source = opts_sio
    expect(subject.test1).to eq 'something1'
    expect(subject.test2).to eq 'something2'
  end

  it 'allows loading options from an array of sources, later sources take precendence' do
    class << subject
      param :test1
      param :test2
    end
    opts_spec1 = opts_spec.clone
    opts_spec1.delete('test1')
    opts_spec1[:test2] = 'something3'

    subject.options_source = [opts_sio, opts_spec1]
    expect(subject.test1).to eq 'something1'
    expect(subject.test2).to eq 'something3'
  end

  it 'allows loading options from sources several times, later sources take precendence' do
    class << subject
      param :test1
      param :test2
    end
    opts_spec1 = opts_spec.clone
    opts_spec1.delete('test1')
    opts_spec1[:test2] = 'something3'

    subject.options_source = opts_sio
    subject.options_source = opts_spec1
    expect(subject.test1).to eq 'something1'
    expect(subject.test2).to eq 'something3'
  end

  it 'does not allow loading options from an arbitrary value' do
    class << subject
      param :test1
      param :test2
    end
    [10, 'test1=1;test2=2', nil].each do |value|
      expect { subject.options_source = value }.to raise_error
    end
  end

  it 'allows loading options from File/IO' do
    subject1 = nil
    subject2 = nil
    subject3 = nil
    f = Tempfile.new('test_options.yaml')
    begin
      f << opts_spec.to_yaml
      f.open
      subject1 = TestIoSubjectClass.new.configure(options_source: f)
      subject2 = TestIoSubjectClass.new.configure(options_source: f.path)
      File.open(f.path) do |real_f|
        subject3 = TestIoSubjectClass.new.configure(options_source: real_f)
      end
    ensure
      f.close
      f.unlink
    end
    [
      subject1,
      subject2,
      subject3
    ].each do |s|
      expect(s).not_to be_nil
      expect(s.test1).to eq 'something1'
      expect(s.test2).to eq 'something2'
    end
  end

  it 'allows specifying defaults' do
    class << subject
      param :test, default: 'something3'
    end
    expect(subject.test).to eq 'something3'
  end

  it 'allows restriciting value classes' do
    class << subject
      param :test, must_be: [Array, Hash]
    end
    expect { subject.test = [] }.not_to raise_error
    expect { subject.test = {} }.not_to raise_error
    expect { subject.test = nil }.to raise_error
    expect { subject.test = '' }.to raise_error
  end
  it 'allows restriciting value classes through duck typing' do
    class << subject
      param :test, must_respond_to: [:each_pair, :size]
    end
    expect { subject.test = [] }.to raise_error
    expect { subject.test = {} }.not_to raise_error # the only one to respond to both :each_pair AND :size
    expect { subject.test = nil }.to raise_error
    expect { subject.test = '' }.to raise_error
  end

  it 'allows locking selected variables' do
    class << subject
      param :test1, lockable: true
      param :test2
    end
    expect { subject.test1 = '1' }.not_to raise_error
    expect { subject.test2 = '1' }.not_to raise_error
    expect(subject.test1).to eq '1'
    expect(subject.test2).to eq '1'

    subject.lock
    expect(subject.is_locked).to eq true
    expect { subject.test1 = '2' }.to raise_error
    expect { subject.test2 = '2' }.not_to raise_error
    expect(subject.test1).to eq '1'
    expect(subject.test2).to eq '2'

    subject.lock(false)
    expect(subject.is_locked).to eq false
    expect { subject.test1 = '3' }.not_to raise_error
    expect { subject.test2 = '3' }.not_to raise_error
    expect(subject.test1).to eq '3'
    expect(subject.test2).to eq '3'
  end

  it 'allows restricting setting nil or empty variables' do
    class << subject
      param :test1, not_nil: true
      param :test2, not_empty: true
    end
    expect { subject.test1 = '1' }.not_to raise_error
    expect { subject.test2 = '1' }.not_to raise_error
    expect(subject.test1).to eq '1'
    expect(subject.test2).to eq '1'

    expect { subject.test1 = nil }.to raise_error
    expect { subject.test2 = nil }.to raise_error
    expect(subject.test1).to eq '1'
    expect(subject.test2).to eq '1'

    expect { subject.test1 = '' }.not_to raise_error
    expect { subject.test2 = '' }.to raise_error
    expect(subject.test1).to eq ''
    expect(subject.test2).to eq '1'
  end

  it 'allows converting to pre-defined types' do
    class << subject
      param :test_s, make_string: true
      param :test_a, make_array: true
      param :test_h, make_hash: true
      param :test_i, make_int: true
      param :test_f, make_float: true
      param :test_b, make_bool: true
    end
    expect { subject.test_s = nil }.not_to raise_error
    expect(subject.test_s).to be_a String
    expect(subject.test_s).to eq ''

    expect { subject.test_a = nil }.not_to raise_error
    expect(subject.test_a).to be_a Array
    expect(subject.test_a).to eq []

    expect { subject.test_h = nil }.not_to raise_error
    expect(subject.test_h).to be_a Hash
    expect(subject.test_h).to eq Hash.new

    expect { subject.test_i = nil }.not_to raise_error
    expect(subject.test_i).to be_a Integer
    expect(subject.test_i).to eq 0

    expect { subject.test_f = nil }.not_to raise_error
    expect(subject.test_f).to be_a Float
    expect(subject.test_f).to eq 0.0

    expect { subject.test_b = nil }.not_to raise_error
    expect(subject.test_b).to be_a FalseClass
    expect(subject.test_b).to eq false
  end

  it 'allows defining min/max boundaries for values' do
    class << subject
      param :test1, min: 10
      param :test2, max: 'c'
    end

    expect { subject.test1 = 11 }.not_to raise_error
    expect { subject.test1 = 10 }.not_to raise_error
    expect { subject.test1 = 9 }.to raise_error

    expect { subject.test2 = 'b' }.not_to raise_error
    expect { subject.test2 = 'c' }.not_to raise_error
    expect { subject.test2 = 'd' }.to raise_error
  end

  it 'allows defining ranges for values' do
    class << subject
      param :test1, in: 3..7
      param :test2, in: %w(a c)
    end

    expect { subject.test1 = 3 }.not_to raise_error
    expect { subject.test1 = 6 }.not_to raise_error
    expect { subject.test1 = 9 }.to raise_error

    expect { subject.test2 = 'a' }.not_to raise_error
    expect { subject.test2 = 'c' }.not_to raise_error
    expect { subject.test2 = 'b' }.to raise_error
  end

  it 'allows specifying a custom conversion method' do
    class Parent
      def check_for_x(value)
        raise 'X is not allowed' if value == 'x'
        'ok'
      end
    end
    subject.set_parent_object(Parent.new)
    class << subject
      param :test1, convert: :check_for_x
      param :test2, convert: ->(value) { value + 1 }
    end
    expect { subject.test1 = 3 }.not_to raise_error
    expect(subject.test1).to eq 'ok'
    expect { subject.test1 = 'x' }.to raise_error

    expect { subject.test2 = 7 }.not_to raise_error
    expect(subject.test2).to eq 8
  end

  it 'accesses the conversion method from the specified parent object, not itself' do
    class Parent
      def check_for_x2(value)
        raise 'X is not allowed' if value == 'x'
        'ok'
      end
    end
    subject.set_parent_object(Parent.new)
    class << subject
      def check_for_x1(value)
        raise 'X is not allowed' if value == 'x'
        'ok'
      end
      param :test1, convert: :check_for_x1
      param :test2, convert: :check_for_x2
    end
    expect { subject.test1 = 3 }.to raise_error
    expect { subject.test1 = 'x' }.to raise_error

    expect { subject.test2 = 3 }.not_to raise_error
    expect(subject.test2).to eq 'ok'
    expect { subject.test2 = 'x' }.to raise_error
  end
end
