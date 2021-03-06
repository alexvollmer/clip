require "#{File.dirname(__FILE__)}/../lib/clip"
require "rubygems"
require "spec"
require "timeout"

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
      p.optional 'x', 'exclude_from_all', :desc => 'Directories to exclude'
      p.flag 'd', 'allow-dashes', :desc => 'Dashes allowed in definition'
      p.flag 'z', 'allow-dashes-all', :desc => 'Dashes allowed in definition'
    end
  end

  describe "When long command-line parameters are parsed" do

    it "should create accessor methods for declarations" do
      parser = parse('')
      parser.should respond_to(:server)
      parser.should respond_to(:server=)
      parser.should respond_to(:server?)
      parser.should respond_to(:port)
      parser.should respond_to(:port=)
      parser.should respond_to(:port?)
      parser.should respond_to(:files)
      parser.should respond_to(:files=)
      parser.should respond_to(:files?)
      parser.should respond_to(:verbose?)
      parser.should respond_to(:flag_verbose)
      parser.should respond_to(:allow_dashes?)
      parser.should respond_to(:allow_dashes_all?)
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
      parser.server?.should eql(true)
      parser.port.should eql("8080")
      parser.port?.should eql(true)
      parser.should be_valid
      parser.should_not have_errors
    end

    it "should map options with '-' to methods with '_'" do
      parser = parse('--exclude-from /Users --files foo')
      parser.exclude_from.should eql("/Users")
      parser.exclude_from?.should eql(true)
      parser.should be_valid
      parser.should_not have_errors
    end

    it "should map flags with '-' to methods with '_'" do
      parser = parse('--allow-dashes')
      parser.should be_allow_dashes
      parser.should_not be_allow_dashes_all
    end

    it "should map options with multiple '-' to methods with '_'" do
      parser = parse('--exclude-from-all /Users --files foo')
      parser.exclude_from_all.should eql("/Users")
      parser.exclude_from_all?.should eql(true)
      parser.should be_valid
      parser.should_not have_errors
    end

    it "should be invalid for unknown options" do
      parser = parse('--non-existent')
      parser.exclude_from_all?.should eql(false)
      parser.exclude_from?.should eql(false)
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
      parser.server?.should eql(true)
      parser.port.should eql("8080")
      parser.port?.should eql(true)
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

  describe "Multi-valued options" do

    it "should handle multiple value for the same option" do
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
    def opts(args=nil)
      Clip(args) do |o|
        o.req 's', 'server', :desc => 'The server name'
        o.opt 'p', 'port', :desc => 'The port number', :default => 80
        o.flag 'v', 'verbose', :desc => 'Enables verbose output'
        yield o if block_given?
      end
    end

    it "should work if no description given" do
      opts = Clip do |o|
        o.opt 'X', 'no-description'
      end
      help = opts.to_s.split("\n")
      help[1].should == "-X  --no-description  "
    end

    it "should print out some sensible usage info for to_s" do
      help = opts("-s localhost").to_s.split("\n")
      help[0].should match(/Usage/)
      help[1].should == "-s  --server      The server name REQUIRED"
      help[2].should == "-p  --port        The port number (default: 80)"
      help[3].should == "-v  --verbose     Enables verbose output"
    end

    it "should expand columns to largest option name" do
      help = opts("-s localhost") do |o|
        o.opt 'b', 'big-honking-file-list', :desc => 'The file list'
      end.to_s.split("\n")
      help[0].should match(/Usage/)
      help[1].should == "-s  --server                 The server name REQUIRED"
      help[2].should == "-p  --port                   The port number (default: 80)"
      help[3].should == "-v  --verbose                Enables verbose output"
      help[4].should == "-b  --big-honking-file-list  The file list"
    end

    it "should wrap column descriptions to fit 80 columns" do
      opts = Clip do |o|
        o.opt 'd', 'description',
              :desc => 'An unending stream of words that goes on endlessly for an eternity until, at last, they stop.',
              :default => 'wordy'
      end
      help = opts.to_s.split("\n")
      help[1].should == "-d  --description  An unending stream of words that goes on endlessly for an"
      help[2].should == "                   eternity until, at last, they stop. (default: wordy)"
    end

    it "should include error messages in to_s" do
      parser = parse('')
      out = parser.to_s.split("\n")
      out[0].should match(/Error/)
      out[1].should match(/missing required.*files/i)
      out[2..-1].join("\n").strip.should == parser.help.strip
    end

    it "should support declaring a banner" do
      opts = Clip('-v') do |p|
        p.banner = "USAGE foo bar baz"
        p.flag 'v', 'verbose', :desc => 'Provide verbose output'
      end

      out = opts.to_s.split("\n")
      out[0].should == 'USAGE foo bar baz'
    end

    it "should handle Travis' degenerate infinite-loop case" do
     opts = Clip('-c') do |c|
        c.flag('c',
               'no-close-session',
               :desc => 'Close the session after successful import?')
        c.flag('l',
               'live-site',
               :desc => "Query live wikipedia site for wiki text instead of DB session")
      end

      help = Timeout.timeout(2) { opts.to_s.split("\n") }
      help[0].should match(/Usage/)
      help[1].should == "-c  --no-close-session  Close the session after successful import?"
      help[2].should == "-l  --live-site         Query live wikipedia site for wiki text instead of DB"
      help[3].should == "                        session"
    end

    it "should support overriding help flags" do
      opts = Clip('-?') do |p|
        p.opt 'h', 'host', :desc => 'The hostname'
        p.help_with '?'
      end
      help = opts.to_s.split("\n")
      help[0].should match(/Usage/)
      help[1].should match(/-h\s+--host\s+The hostname/)
    end
  end

  describe "Remaining arguments" do
    it "should be taken following parsed arguments" do
      parser = parse('--files foo alpha bravo')
      parser.files.should == %w[foo]
      parser.remainder.should == %w[alpha bravo]
    end

    it "should be taken preceeding parsed arguments" do
      parser = parse('alpha bravo --files foo')
      parser.files.should == %w[foo]
      parser.remainder.should == %w[alpha bravo]
    end

    it "should be available when only flags are declared" do
      opts = Clip('foobar') do |p|
        p.flag 'v', 'verbose'
        p.flag 'd', 'debug'
      end
      opts.remainder.should == ['foobar']
      opts.should_not be_verbose
      opts.should_not be_debug
    end

    it "should be available when flags are declared and parsed" do
      opts = Clip('-v foobar') do |p|
        p.flag 'v', 'verbose'
        p.flag 'd', 'debug'
      end
      opts.remainder.should == ['foobar']
      opts.should be_verbose
      opts.should_not be_debug
    end

    it "Should handle quoted strings correctly" do
      opts = Clip(%q(-- "param 1" 'param 2' param\ 3)) {|p|}
      opts.remainder.should include('param 1', 'param 2', 'param 3')
    end
  end
  describe "Remaining arguments for Clip.hash" do
    before(:each) { Clip.reset_hash! }

    it "should be populated" do
      Clip.hash(['captain', 'lieutenant', '-c', 'jorge']).remainder.
        should == ['captain', 'lieutenant']
    end

    it "should be empty for an empty arg list" do
      Clip.hash([]).remainder.should be_empty
    end

    it "should be empty for a completely-parsed arg list" do
      Clip.hash(['-c', '/etc/clip.yml']).remainder.should be_empty
    end

    it "should be the arg list for an unparsed arg list" do
      Clip.hash(['git', 'bzr', 'hg', 'darcs', 'arch']).remainder.
        should == ['git', 'bzr', 'hg', 'darcs', 'arch']
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

    it "should reject '-' as a short option" do
      misconfig_parser { |c| c.flag '-', 'foo' }
    end

    it "should reject long parameters that do not start with a word character" do
      misconfig_parser { |c| c.optional 'o', '-foo' }
      misconfig_parser { |c| c.optional 'o', '-' }
    end

    it "should reject options with non-word characters '-' ok" do
      misconfig_parser { |c| c.flag '#', 'count' }
      misconfig_parser { |c| c.flag 'c', 'bang!' }
      misconfig_parser { |c| c.optional '#', 'count' }
      misconfig_parser { |c| c.optional 'c', 'bang!' }
    end

    it "should reject short params that aren't single characters" do
      misconfig_parser { |c| c.optional 'foo', 'foo' }
    end

    it "should reject :help as a flag name" do
      misconfig_parser { |c| c.flag 'x', 'help' }
    end

    it "should reject :help as an optional name" do
      misconfig_parser { |c| c.optional 'x', 'help' }
    end

    it "should reject '?' as a short flag name" do
      misconfig_parser { |c| c.flag '?', 'foo' }
    end

    it "should reject '?' as a short parameter name" do
      misconfig_parser { |c| c.optional '?', 'foo' }
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

  describe "when specifying a block for a parameter" do
    it "should run the block" do
      opts = Clip("-v 123") do |c|
        c.req 'v', 'value', :desc => 'The value' do |v|
          v.to_i
        end
      end

      opts.value.should == 123
    end

    it "should trap exceptions from block and report error" do
      opts = Clip("-v 123") do |c|
        c.req('v', 'value') {|v| raise("a good error message") }
      end

      opts.should_not be_valid
      opts.should have_errors
      opts.should have_errors_on(:value)
    end
  end

  describe "when parsing ARGV as a hash" do
    before(:each) { Clip.reset_hash! }

    it "should make sense of '-c my_config.yml'" do
      Clip.hash(['-c', 'config.yml']).should == { 'c' => 'config.yml' }
    end

    it "should treat flag-style arguments as booleans" do
      Clip.hash(['-f', '-c', 'config.yml', '-d']).
        should == { 'c' => 'config.yml', 'd' => true, 'f' => true }
    end

    it "should ignore leading/trailing non-dashed arguments" do
      Clip.hash(['subcommand', '-c', 'config.yml',
                 'do']).should == { 'c' => 'config.yml' }
    end

    it "should allow -s (short) or --long arguments" do
      Clip.hash(['-c', 'config.yml', '--mode', 'optimistic']).
        should == { 'c' => 'config.yml', 'mode' => 'optimistic' }
    end

    it "should return an empty hash for empty ARGV" do
      Clip.hash([]).should == {}
    end
  end

  describe "stopping parsing after finding --" do
    it "should not blow up" do
      opts = Clip('--') {|p|}
      opts.should be_valid
      opts.remainder.should be_empty
    end

    it "should not parse after --" do
      opts = Clip('-- --help') {|p|}
      opts.should be_valid
      opts.remainder.should include('--help')
    end

    it "should parse args before --" do
      opts = Clip('-v -- other stuff') do |p|
        p.flag 'v', 'verbose'
      end
      opts.should be_valid
      opts.should be_verbose
      opts.remainder.should include('other', 'stuff')
    end
  end
end
