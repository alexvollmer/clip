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

describe Clip do

  def parse(line)
    Clip(line) do |p|
      p.flag 'v', 'verbose', :desc => 'Provide verbose output'
      p.optional 's', 'server', :desc => 'The hostname', :default => 'localhost'
      p.optional 'p', 'port', :desc => 'The port number', :default => 8080
      p.required 'f', 'files', :desc => 'Files to upload', :multi => true
      p.optional 'e', 'exclude_from', :desc => 'Directories to exclude'
    end
  end

  describe "When long command-line parameters are parsed" do  

    it "should create accessor methods for declarations" do
      parser = parse('')
      parser.should respond_to(:server)
      parser.should respond_to(:server=)
      parser.should respond_to(:port)
      parser.should respond_to(:port)
      parser.should respond_to(:files)
      parser.should respond_to(:files=)
      parser.should respond_to(:verbose?)
      parser.should respond_to(:flag_verbose)
    end

    it "should set fields for flags to 'true'" do
      parser = parse('--verbose --files foo')
      parser.should be_verbose
      parser.should be_valid
      parser.should_not have_errors
    end
  
    it "should set fields for flags with the given values" do
      parser = parse('--server localhost --port 8080 --files foo')
      parser.server.should eql("localhost")
      parser.port.should eql("8080")
      parser.should be_valid
      parser.should_not have_errors
    end

    it "should map flags with '-' to methods with '_'" do
      parser = parse('--exclude-from /Users --files foo')
      parser.exclude_from.should eql("/Users")
      parser.should be_valid
      parser.should_not have_errors
    end

    it "should be invalid for unknown flags" do
      parser = parse('--non-existent')
      parser.should_not be_valid
      parser.should have_errors_on(:non_existent)
    end
  end

  describe "When short (single-letter) command-line parse are parsed" do
  
    it "should set flags to true" do
      parser = parse("-v --files foo")
      parser.should be_verbose
      parser.should_not have_errors
      parser.should be_valid
    end
  
    it "should set fields for short options" do
      parser = parse("-s localhost -p 8080 --files foo")
      parser.should_not have_errors
      parser.should be_valid
      parser.server.should eql("localhost")
      parser.port.should eql("8080")
      parser.should_not be_verbose
    end
  end

  describe "When parameters are marked as required" do
  
    it "should be invalid when there are missing arguments" do
      parser = parse('--server localhost')
      parser.should_not be_valid
      parser.should have_errors_on(:files)
    end
  end

  describe "When parameters are marked with defaults" do
  
    it "should provide default parameter values when none are parsed" do
      parser = parse('--files foo')
      parser.should be_valid
      parser.should_not have_errors
      parser.server.should eql("localhost")
      parser.port.should eql(8080)
    end
  end

  describe "Multi-valued parameters" do

    it "should handle multiple value for the same parameter" do
      parser = parse("--files foo --files bar --files baz")
      parser.should be_valid
      parser.should_not have_errors
      parser.files.should == %w[foo bar baz]
    end

    it "should handle comma-separated values as multiples" do
      parser = parse("--files foo,bar,baz")
      parser.should be_valid
      parser.should_not have_errors
      parser.files.should == %w[foo bar baz]
    end
  end

  describe "Help output" do
    it "should print out some sensible usage info for to_s" do
      out = parse('--files foo').to_s.split("\n")
      out[0].should match(/Usage/)
      out[1].should match(/-v\s+--verbose\s+Provide verbose output/)
      out[2].should match(/-s\s+--server\s+The hostname.*default.*localhost/)
      out[3].should match(/-p\s+--port\s+The port number/)
      out[4].should match(/-f\s+--files\s+Files to upload.*REQUIRED/)
      out[5].should match(/-e\s+--exclude-from\s+Directories to exclude/)
    end

    it "should include error messages in to_s" do
      parser = parse('')
      out = parser.to_s.split("\n")
      out[0].should match(/Error/)
      out[1].should match(/missing required.*files/i)
      out[2..-1].join("\n").strip.should == parser.help.strip
    end
  end

  describe "Additional arguments" do
    it "should be made available" do
      parser = parse('--files foo alpha bravo')
      parser.files.should == %w[foo]
      parser.remainder.should == %w[alpha bravo]
    end
  end

  describe "Declaring bad options and flags" do

    def misconfig_parser
      lambda do
        Clip("foo") do |c|
          yield c
        end
      end.should raise_error(Clip::IllegalConfiguration)
    end

    it "should reject :help as a flag name" do
      misconfig_parser { |c| c.flag 'x', 'help' }
    end

    it "should reject :help as an optional name" do
      misconfig_parser { |c| c.optional 'x', 'help' }
    end

    it "should reject 'h' as a short flag name" do
      misconfig_parser { |c| c.flag 'h', 'foo' }
    end

    it "should reject 'h' as a short parameter name" do
      misconfig_parser { |c| c.optional 'h', 'foo' }
    end

    it "should reject redefining an existing long name for two options" do
      misconfig_parser do |c|
        c.optional 'f', 'foo'
        c.optional 'x', 'foo'
      end
    end

    it "should reject redefining an existing long name for an option & flag" do
      misconfig_parser do |c|
        c.optional 'f', 'foo'
        c.flag 'x', 'foo'
      end
    end

    it "should reject redefining the same flag" do
      misconfig_parser do |c|
        c.flag 'f', 'foo'
        c.flag 'x', 'foo'
      end
    end

    it "should reject defining a flag with an option" do
      misconfig_parser do |c|
        c.flag 'f', 'foo'
        c.optional 'x', 'foo'
      end
    end

    it "should reject redefining an existing short name for options" do
      misconfig_parser do |c|
        c.optional 'f', 'foo'
        c.optional 'f', 'files'
      end
    end

    it "should reject redefining a short option with a flag" do
      misconfig_parser do |c|
        c.optional 'f', 'foo'
        c.flag 'f', 'fail'
      end
    end

    it "should reject redefining a short flag with a flag" do
      misconfig_parser do |c|
        c.flag 'f', 'fail'
        c.flag 'f', 'foo'
      end
    end

    it "should reject redefining a flag with an optional" do
      misconfig_parser do |c|
        c.flag 'f', 'fail'
        c.optional 'f', 'foo'
      end
    end
  end
end
