require "#{File.dirname(__FILE__)}/../lib/clip"
require "rubygems"
require "spec"

class HaveErrors

  def matches?(target)
    @target = target
    not @target.errors.empty?
  end

  def failure_message
    "expected #{@target} to have errors"
  end

  def negative_failure_message
    "expected #{@target} to have no errors, but... #{@target.errors.inspect}"
  end
end

def have_errors
  HaveErrors.new
end

class HaveErrorsOn
  def initialize(expected)
    @expected = expected
  end

  def matches?(target)
    @target = target
    not @target.errors[@expected.to_sym].nil?
  end

  def failure_message
    "expected error message for #{@expected} on #{@target}"
  end

  def negative_failure_message
    "unexpected error message for #{@expected} on #{@target}"
  end
end

def have_errors_on(expected)
  HaveErrorsOn.new(expected)
end

describe "When long command-line parameters are parsed" do  
  before do
    class TestParser < Clip::Parser
      flag :verbose
      flag :debug
      optional :host
      optional :port
      optional :exclude_from
    end
    @parser = TestParser.new
  end

  it "should create accessor methods for declarations" do
    @parser.should respond_to(:host)
    @parser.should respond_to(:host=)
    @parser.should respond_to(:port)
    @parser.should respond_to(:port)
    @parser.should respond_to(:exclude_from)
    @parser.should respond_to(:exclude_from=)
    @parser.should respond_to(:verbose?)
    @parser.should respond_to(:flag_verbose)
    @parser.should respond_to(:debug?)
    @parser.should respond_to(:flag_debug)
  end

  it "should set fields for flags with no values to 'true'" do
    @parser.parse '--verbose --debug'
    @parser.should be_debug
    @parser.should be_verbose
    @parser.should be_valid
    @parser.should_not have_errors
  end
  
  it "should set fields for flags with the given values" do
    @parser.parse '--host localhost --port 8080'
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
    @parser.should be_valid
    @parser.should_not have_errors
  end

  it "should map flags with '-' to methods with '_'" do
    @parser.parse '--exclude-from /Users'
    @parser.exclude_from.should eql("/Users")
    @parser.should be_valid
    @parser.should_not have_errors
  end

  it "should be invalid for unknown flags" do
    @parser.parse '--non-existent'
    @parser.should_not be_valid
    @parser.should have_errors_on(:non_existent)
  end
end

describe "When short (single-letter) command-line parse are parsed" do
  before do
    class ShortParser < Clip::Parser
      optional :host, :short => "h"
      optional :port, :short => "p"
      flag :verbose, :short => "v"
    end
    @parser = ShortParser.new
  end
  
  it "should set flags to true" do
    @parser.parse("-v")
    @parser.should be_verbose
    @parser.should_not have_errors
    @parser.should be_valid
  end
  
  it "should set fields for short options" do
    @parser.parse("-h localhost -p 8080")
    @parser.should_not have_errors
    @parser.should be_valid
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
    @parser.should_not be_verbose
  end
end

describe "When usage for the parser is requested" do
  before do
    class UsageParser < Clip::Parser
      optional :host, :short => "h", :desc => "The hostname", :default => "localhost"
      required :port, :short => "p", :desc => "The port number"
    end
    @parser = UsageParser.new
  end

  it "should print usage correctly" do
    out = @parser.help.split("\n")
    out[0].should match(/Usage/)
    out[1].should match(/--host\s+-h\s+The hostname.*default.*localhost/)
    out[2].should match(/--port\s+-p\s+The port number.*REQUIRED/)
  end
end

describe "When parameters are marked as required" do
  before do
    class RequiredParser < Clip::Parser
      optional :host
      required :port
    end
    @parser = RequiredParser.new
  end
  
  it "should parse successfully when all required arguments are given" do
    @parser.parse '--host localhost --port 8080'
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
    @parser.should be_valid
    @parser.should_not have_errors
  end

  it "should be invalid when there are missing arguments" do
    @parser.parse '--host localhost'
    @parser.should_not be_valid
    @parser.should have_errors_on(:port)
  end
end

describe "When parameters are marked with defaults" do
  before do
    class DefaultParser < Clip::Parser
      optional "host", :default => "localhost"
    end
    @parser = DefaultParser.new
  end
  
  it "should use parsed parameter values" do
    @parser.parse '--host foobar'
    @parser.should be_valid
    @parser.should_not have_errors
    @parser.host.should eql("foobar")
  end
  
  it "should provide default parameter values when none are parsed" do
    @parser.parse ''
    @parser.should be_valid
    @parser.should_not have_errors
    @parser.host.should eql("localhost")
  end
end

describe "When specifying flags" do
  before(:each) do
    class FlagParser < Clip::Parser
      flag :verbose, :short => 'v'
      flag :debug
    end
    @parser = FlagParser.new
  end

  it "should create accessor methods" do
    @parser.should respond_to(:flag_verbose)
    @parser.should respond_to(:verbose?)
    @parser.should respond_to(:flag_debug)
    @parser.should respond_to(:debug?)
  end

  it "should indicate given flags" do
    @parser.parse '--debug --verbose'
    @parser.should be_valid
    @parser.should_not have_errors
    @parser.should be_debug
    @parser.should be_verbose
  end

  it "should indicate missing flags" do
    @parser.parse ''
    @parser.should_not be_debug
    @parser.should_not be_verbose
    @parser.should be_valid
    @parser.should_not have_errors
  end

  it "should support short-name versions" do
    @parser.parse '-v'
    puts @parser.errors
    @parser.errors.should be_empty
    @parser.should be_valid
    @parser.should_not have_errors
  end
end

describe "Multi-valued parameters" do
  before(:each) do
    class TestParser < Clip::Parser
      optional :files, :multi => true
    end
    @parser = TestParser.new
  end

  it "should handle multiple value for the same parameter" do
    @parser.parse("--files foo --files bar --files baz")
    @parser.should be_valid
    @parser.should_not have_errors
    @parser.files.should == %w[foo bar baz]
  end
end

describe "Help output" do
  it "should print out some sensible usage info for to_s"
  it "should include error messages in to_s"
end

describe "Pathological conditions" do
  it "should flag errors correctly for flags that are given parameters"
end
