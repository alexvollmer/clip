require "#{File.dirname(__FILE__)}/../lib/cli_parser"
require "rubygems"
require_gem "rspec"

describe "When long command-line parameters are parsed" do  
  before do
    class TestParser < CliParser
      opt :verbose
      opt :debug
      opt :host 
      opt :port
      opt :exclude_from
    
      def in_debug?
        @debug == true
      end
  
      def verbose?
        @verbose == true
      end
    end
    @parser = TestParser.new
  end
  
  it "should set fields for flags with no values to 'true'" do
    @parser.parse %w(--verbose --debug)
    @parser.should be_in_debug
    @parser.should be_verbose
  end
  
  it "should set fields for flags with the given values" do
    @parser.parse %w(--host localhost --port 8080)
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
  end

  it "should map flags with '-' to methods with '_'" do
    @parser.parse %w(--exclude-from /Users)
    @parser.exclude_from.should eql("/Users")
  end
  
  it "should raise UnrecognizedOption exception for unknown flags" do
    lambda { @parser.parse %w(--non-existent) }.should raise_error(UnrecognizedOption)
  end  
end

describe "When short (single-letter) command-line parse are parsed" do
  before do
    class ShortParser < CliParser
      opt :host, :short => "h"
      opt :port, :short => "p"
      opt :verbose, :short => "v"
      
      def verbose?
        @verbose == true
      end
    end
    @parser = ShortParser.new
  end
  
  it "should set fields to true when no arguments are given" do
    @parser.parse("-v")
    @parser.should be_verbose
  end
  
  it "should set fields for short options" do
    @parser.parse("-h localhost -p 8080")
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
  end
end

describe "When usage for the parser is requested" do
  before do
    class UsageParser < CliParser
      opt "host", :short => "h", :desc => "The hostname", :default => "localhost"
      opt "port", :short => "p", :desc => "The port number", :required => true
    end
    @parser = UsageParser.new
  end

  it "should print usage for each option in the order defined, displaying defaults (if given) and required parameters" do
    out = ""
    @parser.help(out)    
    out.should eql(<<USAGE)
Usage:
--host -h The hostname (defaults to 'localhost')
--port -p The port number REQUIRED
USAGE
  end
end

describe "When parameters are marked as required" do
  before do
    class RequiredParser < CliParser
      opt "host"
      opt "port", :required => true
    end
    @parser = RequiredParser.new
  end
  
  it "should parse successfully when all required arguments are given" do
    @parser.parse %w(--host localhost --port 8080)
    @parser.host.should eql("localhost")
    @parser.port.should eql("8080")
  end
  
  it "should throw MissingArgument when there are missing arguments" do
    lambda { @parser.parse %w(--host localhost) }.should raise_error(MissingArgument)
  end
end

describe "When parameters are marked with defaults" do
  before do
    class DefaultParser < CliParser
      opt "host", :default => "localhost"
    end
    @parser = DefaultParser.new
  end
  
  it "should use parsed parameter values" do
    @parser.parse %w(--host foobar)
    @parser.host.should eql("foobar")
  end
  
  it "should provide default parameter values when none are parsed" do
    @parser.parse []
    @parser.host.should eql("localhost")
  end
end