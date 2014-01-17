#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/resolution'

describe Facter::Util::Resolution do
  include FacterSpec::ConfigHelper

  it "should require a name" do
    lambda { Facter::Util::Resolution.new }.should raise_error(ArgumentError)
  end

  it "should have a name" do
    Facter::Util::Resolution.new("yay").name.should == "yay"
  end

  it "should be able to set the value" do
    resolve = Facter::Util::Resolution.new("yay")
    resolve.value = "foo"
    resolve.value.should == "foo"
  end

  it "should have a method for setting the weight" do
    Facter::Util::Resolution.new("yay").should respond_to(:has_weight)
  end

  it "should have a method for setting the code" do
    Facter::Util::Resolution.new("yay").should respond_to(:setcode)
  end

  it "should support a timeout value" do
    Facter::Util::Resolution.new("yay").should respond_to(:timeout=)
  end

  it "should default to a timeout of 0 seconds" do
    Facter::Util::Resolution.new("yay").limit.should == 0
  end

  it "should default to nil for code" do
    Facter::Util::Resolution.new("yay").code.should be_nil
  end

  it "should default to nil for interpreter" do
    Facter.expects(:warnonce).with("The 'Facter::Util::Resolution.interpreter' method is deprecated and will be removed in a future version.")
    Facter::Util::Resolution.new("yay").interpreter.should be_nil
  end

  it "should provide a 'limit' method that returns the timeout" do
    res = Facter::Util::Resolution.new("yay")
    res.timeout = "testing"
    res.limit.should == "testing"
  end

  describe "when setting the code" do
    before do
      Facter.stubs(:warnonce)
      @resolve = Facter::Util::Resolution.new("yay")
    end

    it "should deprecate the interpreter argument to 'setcode'" do
      Facter.expects(:warnonce).with("The interpreter parameter to 'setcode' is deprecated and will be removed in a future version.")
      @resolve.setcode "foo", "bar"
      @resolve.interpreter.should == "bar"
    end

    it "should deprecate the interpreter= method" do
      Facter.expects(:warnonce).with("The 'Facter::Util::Resolution.interpreter=' method is deprecated and will be removed in a future version.")
      @resolve.interpreter = "baz"
      @resolve.interpreter.should == "baz"
    end

    it "should deprecate the interpreter method" do
      Facter.expects(:warnonce).with("The 'Facter::Util::Resolution.interpreter' method is deprecated and will be removed in a future version.")
      @resolve.interpreter
    end

    it "should set the code to any provided string" do
      @resolve.setcode "foo"
      @resolve.code.should == "foo"
    end

    it "should set the code to any provided block" do
      block = lambda { }
      @resolve.setcode(&block)
      @resolve.code.should equal(block)
    end

    it "should prefer the string over a block" do
      @resolve.setcode("foo") { }
      @resolve.code.should == "foo"
    end

    it "should fail if neither a string nor block has been provided" do
      lambda { @resolve.setcode }.should raise_error(ArgumentError)
    end
  end

  describe 'callbacks when flushing facts' do
    class FlushFakeError < StandardError; end

    subject do
      Facter::Util::Resolution.new("jeff")
    end

    context '#on_flush' do
      it 'accepts a block with on_flush' do
        subject.on_flush() { raise NotImplementedError }
      end
    end

    context '#flush' do
      it 'calls the block passed to on_flush' do
        subject.on_flush() { raise FlushFakeError }
        expect { subject.flush }.to raise_error FlushFakeError
      end
    end
  end

  it "should be able to return a value" do
    Facter::Util::Resolution.new("yay").should respond_to(:value)
  end

  describe "when returning the value" do
    let(:fact_value) { "" }

    let(:utf16_string) do
      if String.method_defined?(:encode) && defined?(::Encoding)
        fact_value.encode(Encoding::UTF_16LE).freeze
      else
        [0x00, 0x00].pack('C*').freeze
      end
    end

    let(:expected_value) do
      if String.method_defined?(:encode) && defined?(::Encoding)
        fact_value.encode(Encoding::UTF_8).freeze
      else
        [0x00, 0x00].pack('C*').freeze
      end
    end

    before do
      @resolve = Facter::Util::Resolution.new("yay")
    end

    it "should return any value that has been provided" do
      @resolve.value = "foo"
      @resolve.value.should == "foo"
    end

    describe "and setcode has not been called" do
      it "should return nil" do
        Facter::Util::Resolution.expects(:exec).with(nil, nil).never
        @resolve.value.should be_nil
      end
    end

    describe "and the code is a string" do
      it "should return the result of executing the code" do
        @resolve.setcode "/bin/foo"
        Facter::Util::Resolution.expects(:exec).once.with("/bin/foo").returns "yup"

        @resolve.value.should == "yup"
      end

      it "it normalizes the resolved value" do
        @resolve.setcode "/bin/foo"

        Facter::Util::Resolution.expects(:exec).once.returns(utf16_string)

        expect(@resolve.value).to eq(expected_value)
      end

      describe "on non-windows systems" do
        before do
          given_a_configuration_of(:is_windows => false)
        end

        it "should return the result of executing the code" do
          @resolve.setcode "/bin/foo"
          Facter::Util::Resolution.expects(:exec).once.with("/bin/foo").returns "yup"

          @resolve.value.should == "yup"
        end

        it "it normalizes the resolved value" do
          @resolve.setcode "/bin/foo"

          Facter::Util::Resolution.expects(:exec).once.returns(utf16_string)

          expect(@resolve.value).to eq(expected_value)
        end
      end
    end

    describe "and the code is a block" do
      it "should warn but not fail if the code fails" do
        @resolve.setcode { raise "feh" }
        Facter.expects(:warn)
        @resolve.value.should be_nil
      end

      it "should return the value returned by the block" do
        @resolve.setcode { "yayness" }
        @resolve.value.should == "yayness"
      end

      it "it normalizes the resolved value" do
        @resolve.setcode { utf16_string }

        expect(@resolve.value).to eq(expected_value)
      end

      it "should use its limit method to determine the timeout, to avoid conflict when a 'timeout' method exists for some other reason" do
        @resolve.expects(:timeout).never
        @resolve.expects(:limit).returns "foo"
        Timeout.expects(:timeout).with("foo")

        @resolve.setcode { sleep 2; "raise This is a test"}
        @resolve.value
      end

      it "should timeout after the provided timeout" do
        Facter.expects(:warn)
        @resolve.timeout = 0.1
        @resolve.setcode { sleep 2; raise "This is a test" }
        Thread.expects(:new).yields

        @resolve.value.should be_nil
      end

      it "should waitall to avoid zombies if the timeout is exceeded" do
        Facter.stubs(:warn)
        @resolve.timeout = 0.1
        @resolve.setcode { sleep 2; raise "This is a test" }

        Thread.expects(:new).yields
        Process.expects(:waitall)

        @resolve.value
      end
    end
  end

  it "should return its value when converted to a string" do
    @resolve = Facter::Util::Resolution.new("yay")
    @resolve.expects(:value).returns "myval"
    @resolve.to_s.should == "myval"
  end

  it "should allow the adding of confines" do
    Facter::Util::Resolution.new("yay").should respond_to(:confine)
  end

  it "should provide a method for returning the number of confines" do
    @resolve = Facter::Util::Resolution.new("yay")
    @resolve.confine "one" => "foo", "two" => "fee"
    @resolve.weight.should == 2
  end

  it "should return 0 confines when no confines have been added" do
    Facter::Util::Resolution.new("yay").weight.should == 0
  end

  it "should provide a way to set the weight" do
    @resolve = Facter::Util::Resolution.new("yay")
    @resolve.has_weight(45)
    @resolve.weight.should == 45
  end

  it "should allow the weight to override the number of confines" do
    @resolve = Facter::Util::Resolution.new("yay")
    @resolve.confine "one" => "foo", "two" => "fee"
    @resolve.weight.should == 2
    @resolve.has_weight(45)
    @resolve.weight.should == 45
  end

  it "should have a method for determining if it is suitable" do
    Facter::Util::Resolution.new("yay").should respond_to(:suitable?)
  end

  describe "when adding confines" do
    before do
      @resolve = Facter::Util::Resolution.new("yay")
    end

    it "should accept a hash of fact names and values" do
      lambda { @resolve.confine :one => "two" }.should_not raise_error
    end

    it "should create a Util::Confine instance for every argument in the provided hash" do
      Facter::Util::Confine.expects(:new).with("one", "foo")
      Facter::Util::Confine.expects(:new).with("two", "fee")

      @resolve.confine "one" => "foo", "two" => "fee"
    end

    it "should accept a single fact with a block parameter" do
      lambda { @resolve.confine :one do true end }.should_not raise_error
    end

    it "should create a Util::Confine instance for the provided fact with block parameter" do
      block = lambda { true }
      Facter::Util::Confine.expects(:new).with("one")

      @resolve.confine("one", &block)
    end

    it "should accept a single block parameter" do
      lambda { @resolve.confine() do true end }.should_not raise_error
    end

    it "should create a Util::Confine instance for the provided block parameter" do
      block = lambda { true }
      Facter::Util::Confine.expects(:new)

      @resolve.confine(&block)
    end
  end

  describe "when determining suitability" do
    before do
      @resolve = Facter::Util::Resolution.new("yay")
    end

    it "should always be suitable if no confines have been added" do
      @resolve.should be_suitable
    end

    it "should be unsuitable if any provided confines return false" do
      confine1 = mock 'confine1', :true? => true
      confine2 = mock 'confine2', :true? => false
      Facter::Util::Confine.expects(:new).times(2).returns(confine1).then.returns(confine2)
      @resolve.confine :one => :two, :three => :four

      @resolve.should_not be_suitable
    end

    it "should be suitable if all provided confines return true" do
      confine1 = mock 'confine1', :true? => true
      confine2 = mock 'confine2', :true? => true
      Facter::Util::Confine.expects(:new).times(2).returns(confine1).then.returns(confine2)
      @resolve.confine :one => :two, :three => :four

      @resolve.should be_suitable
    end
  end

  describe "setting options" do
    subject(:resolution) { described_class.new(:foo) }

    it "can set the value" do
      resolution.set_options(:value => 'something')
      expect(resolution.value).to eq 'something'
    end

    it "can set the timeout" do
      resolution.set_options(:timeout => 314)
      expect(resolution.limit).to eq 314
    end

    it "can set the weight" do
      resolution.set_options(:weight => 27)
      expect(resolution.weight).to eq 27
    end

    it "fails on unhandled options" do
      expect do
        resolution.set_options(:foo => 'bar')
      end.to raise_error(ArgumentError, /Invalid resolution options.*foo/)
    end
  end
end
