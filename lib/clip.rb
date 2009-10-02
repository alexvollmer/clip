#!/usr/bin/env ruby

require 'shellwords'

##
# Parse arguments (defaults to <tt>ARGV</tt>) with the Clip::Parser
# configured in the given block. This is the main method you
# call to get the ball rolling.
def Clip(args=ARGV)
  parser = Clip::Parser.new
  raise "Dontcha wanna configure your parser?" unless block_given?
  yield parser
  parser.parse(args)
  parser
end

module Clip
  VERSION = "1.0.0"

  ##
  # Indicates that the parser was incorrectly configured in the
  # block yielded by the +parse+ method.
  class IllegalConfiguration < Exception
  end

  class Parser
    ##
    # Returns any remaining command line arguments that were not parsed
    # because they were neither flags or option/value pairs
    attr_reader :remainder

    ##
    # Set the usage 'banner' displayed when calling <tt>to_s</tt> to
    # display the usage message. If not set, the default will be used.
    # If the value is set this completely replaces the default
    attr_accessor :banner

    ##
    # Override the flag to trigger help usage. By default the short
    # flag '-h' and long flag '--help' will trigger displaying usage.
    # If you need to override this, particularly in the case of '-h',
    # call this method
    def help_with(short, long="--help")
      @help_short = short
      @help_long = long
    end

    ##
    # Declare an optional parameter for your parser. This creates an accessor
    # method matching the <tt>long</tt> parameter and a present method 
    # <tt>long?</tt>. The <tt>short</tt> parameter indicates 
    # the single-letter equivalent. Options that use the '-'
    # character as a word separator are converted to method names using
    # '_'. For example the name 'exclude-files' would create two methods named
    # <tt>exclude_files</tt> and <tt>exclude_files?</tt>.
    #
    # When the <tt>:multi</tt> option is enabled, the associated accessor
    # method will return an <tt>Array</tt> instead of a single scalar value.
    # === options
    # Valid options include:
    # * <tt>desc</tt>: a helpful description (used for printing usage)
    # * <tt>default</tt>: a default value to provide if one is not given
    # * <tt>multi</tt>: indicates that mulitple values are okay for this param.
    # * <tt>block</tt>: an optional block to process the parsed value
    #
    # Note that specifying the <tt>:multi</tt> option means that the parameter
    # can be specified several times with different values, or that a single
    # comma-separated value can be specified which will then be broken up into
    # separate tokens.
    def optional(short, long, options={}, &block)
      check_args(short, long)

      short = short.to_sym
      long = long.gsub('-', '_').to_sym

      var_name = "@#{long}".to_sym
      self.class.class_eval do
        define_method("#{long}=".to_sym) do |v|
          begin
            v = yield(v) if block_given?
            instance_variable_set(var_name, v)
          rescue StandardError => e
            @valid = false
            @errors[long] = e.message
          end
        end

        define_method(long.to_sym) do
          instance_variable_get(var_name)
        end
        
        define_method("#{long}?") do
          !instance_variable_get(var_name).nil?
        end
      end

      self.options[short] = self.options[long] =
        Option.new(short, long, options)

      self.order << self.options[long]
      check_longest(long)
    end

    alias_method :opt, :optional

    ##
    # Declare a required parameter for your parser. If this parameter
    # is not provided in the parsed content, the parser instance
    # will be invalid (i.e. where valid? returns <tt>false</tt>).
    #
    # This method takes the same options as the optional method.
    def required(short, long, options={}, &block)
      optional(short, long, options.merge({ :required => true }), &block)
    end

    alias_method :req, :required

    ##
    # Declare a parameter as a simple boolean flag. This declaration
    # will create a "question" method matching the given <tt>long</tt>.
    # For example, declaring with the name of 'verbose' will create a
    # method on your parser called <tt>verbose?</tt>.
    # === options
    # Valid options are:
    # * <tt>desc</tt>: Descriptive text for the flag
    def flag(short, long, options={})
      check_args(short, long)

      short = short.to_sym
      long = long.gsub('-', '_').to_sym
      self.class.class_eval do
        define_method("flag_#{long}") do
          instance_variable_set("@#{long}", true)
        end

        define_method("#{long}?") do
          instance_variable_get("@#{long}")
        end
      end

      self.options[long] = Flag.new(short, long, options)
      self.options[short] = self.options[long]
      self.order << self.options[long]
      check_longest(long)
    end

    def initialize # :nodoc:
      @errors = {}
      @valid = true
      @longest = 10
      @help_long = "--help"
      @help_short = "-h"
    end

    ##
    # Parse the given <tt>args</tt> and set the corresponding instance
    # fields to the given values. If any errors occurred during parsing
    # you can get them from the <tt>Hash</tt> returned by the +errors+ method.
    def parse(args)
      @valid = true
      args = Shellwords::shellwords(args) unless args.kind_of?(Array)
      consumed = []
      option = nil

      args.each do |token|
        case token
        when @help_long, @help_short
          puts help
          exit 0

        when /\A--\z/
          consumed << token
          break

        when /^-(-)?\w/
          consumed << token
          param = token.sub(/^-(-)?/, '').gsub('-', '_').to_sym
          option = options[param]
          if option.nil?
            @errors[param] = "Unrecognized parameter"
            @valid = false
            next
          end

          if option.kind_of?(Flag)
            option.process(self, nil)
            option = nil
          end
        else
          if option
            consumed << token
            option.process(self, token)
            option = nil
          end
        end
      end

      @remainder = args - consumed

      # Find required options that are missing arguments
      options.each do |param, opt|
        if opt.kind_of?(Option) and self.send(opt.long).nil?
          if opt.required?
            @valid = false
            @errors[opt.long.to_sym] = "Missing required parameter: #{opt.long}"
          elsif opt.has_default?
            opt.process(self, opt.default)
          end
        end
      end
    end

    ##
    # Indicates whether or not the parsing process succeeded. If this
    # returns <tt>false</tt> you probably just want to print out a call
    # to the to_s method.
    def valid?
      @valid
    end

    ##
    # Returns a <tt>Hash</tt> of errors (by the long name) of any errors
    # encountered during parsing. If you simply want to display error
    # messages to the user, you can just print out a call to the
    # to_s method.
    def errors
      @errors
    end

    ##
    # Returns a formatted <tt>String</tt> indicating the usage of the parser,
    # formatted to fit within 80 display columns.
    def help
      out = ""
      if banner
        out << "#{banner}\n"
      else
        out << "Usage:\n"
      end

      order.each do |option|
        line = sprintf("-%-2s --%-#{@longest}s  ",
                       option.short,
                       option.long.to_s.gsub('_', '-'))

        out << line
        if line.length + option.description.length <= 80
          out << option.description
        else
          rem = 80 - line.length
          desc = option.description
          i = 0
          while i < desc.length
            out << "\n" if i > 0
            j = [i + rem, desc.length].min
            while desc[j..j] =~ /[\w\d]/
              j -= 1
            end
            chunk = desc[i..j].strip
            out << " " * line.length if i > 0
            out << chunk
            i = j + 1
          end
        end

        if option.has_default?
          out << " (default: #{option.default})"
        end

        if option.required?
          out << " REQUIRED"
        end
        out << "\n"
      end
      out
    end

    ##
    # Returns a formatted <tt>String</tt> of the +help+ method prefixed by
    # any parsing errors. Either way you have _one_ method to call to
    # let your users know what to do.
    def to_s
      out = ""
      unless valid?
        out << "Errors:\n"
        errors.each do |field, msg|
          out << "#{field}: #{msg}\n"
        end
      end
      out << help
    end

    def options # :nodoc:
      (@options ||= {})
    end

    def order # :nodoc:
      (@order ||= [])
    end

    private
    def check_args(short, long)
      if short.size != 1
        raise IllegalConfiguration.new("Short options must be a single character.")
      end

      if short !~ /[\w]+/
        raise IllegalConfiguration.new("Illegal option: #{short}.  Option names can only use [a-zA-Z_-]")
      end

      if long !~ /\A\w[\w-]*\z/
        raise IllegalConfiguration.new("Illegal option: #{long}'.  Parameter names can only use [a-zA-Z_-]")
      end

      short = short.to_sym
      long = long.to_sym

      if long == :help
        raise IllegalConfiguration.new("You cannot override the built-in 'help' parameter")
      end

      if short == '?'.to_sym
        raise IllegalConfiguration.new("You cannot override the built-in '?' parameter")
      end

      if self.options.has_key?(long)
        raise IllegalConfiguration.new("You have already defined a parameter/flag for #{long}")
      end

      if self.options.has_key?(short)
        raise IllegalConfiguration.new("You already have a defined parameter/flag for the short key '#{short}")
      end
    end

    def check_longest(name)
      l = name.to_s.length
      @longest = l if l > @longest
    end
  end

  class Option # :nodoc:
    attr_accessor :long, :short, :description, :default, :required, :multi

    def initialize(short, long, options)
      @short = short
      @long = long
      @description = options[:desc] || ""
      @default = options[:default]
      @required = options[:required]
      @multi = options[:multi]
    end

    def process(parser, value)
      if @multi
        current = parser.send(@long) || []
        current.concat(value.split(','))
        parser.send("#{@long}=".to_sym, current)
      else
        parser.send("#{@long}=".to_sym, value)
      end
    end

    def required?
      @required == true
    end

    def has_default?
      not @default.nil?
    end

    def multi?
      @multi == true
    end

    def usage
      out = sprintf('-%-2s --%-10s %s',
                    @short,
                    @long.to_s.gsub('_', '-').to_sym,
                    @description)
      out << " (defaults to '#{@default}')" if @default
      out << " REQUIRED" if @required
      out
    end
  end

  class Flag # :nodoc:

    attr_accessor :long, :short, :description

    ##
    # nodoc
    def initialize(short, long, options)
      @short = short
      @long = long
      @description = options[:desc]
    end

    def process(parser, value)
      parser.send("flag_#{@long}".to_sym)
    end

    def required?
      false
    end

    def has_default?
      false
    end
  end

  HASHER_REGEX = /^--?(\w+)/
  ##
  # Turns ARGV into a hash.
  #
  #  my_clip_script -c config.yml # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script command -c config.yml # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script com -c config.yml -d # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script -c config.yml --mode optimistic
  #  # Clip.hash == { 'c' => 'config.yml', 'mode' => 'optimistic' }
  #
  # The returned hash also has a +remainder+ method that contains
  # unparsed values.
  #
  def self.hash(argv = ARGV.dup, keys = [])
    return @hash if @hash # used the cached value if available

    opts = Clip(argv) do |clip|
      keys = argv.select{ |a| a =~ HASHER_REGEX }.map do |a|
        a = a.sub(HASHER_REGEX, '\\1')
        clip.optional(a[0,1], a); a
      end
    end

    # The "|| true" on the end is for when no value is found for a
    # key; it's assumed that a flag was meant instead of an optional
    # argument, so it's set to true. A bit weird-looking, but more useful.
    @hash = keys.inject({}) { |h, key| h.merge(key => opts.send(key) || true) }

    # module_eval is necessary to define a singleton method using a closure =\
    (class << @hash; self; end).module_eval do
      define_method(:remainder) { opts.remainder }
    end

    return @hash
  end

  ##
  # Clear the cached hash value. Probably only useful for tests, but whatever.
  def self.reset_hash!; @hash = nil end
end
