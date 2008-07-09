#!/usr/bin/env ruby

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
  VERSION = "0.0.5"

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
    # Declare an optional parameter for your parser. This creates an accessor
    # method matching the <tt>long</tt> parameter. The <tt>short</tt> parameter
    # indicates the single-letter equivalent. Options that use the '-'
    # character as a word separator are converted to method names using
    # '_'. For example the name 'exclude-files' would create a method named
    # <tt>exclude_files</tt>.
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
      short = short.to_sym
      long = long.to_sym
      check_args(short, long)

      var_name = "@#{long}".to_sym
      if block
        self.class.send(:define_method, "#{long}=".to_sym) do |v|
          instance_variable_set(var_name, block.call(v))
        end
      else
        self.class.send(:define_method, "#{long}=".to_sym) do |v|
          instance_variable_set(var_name, v)
        end
      end

      self.class.send(:define_method, long.to_sym) do
        instance_variable_get(var_name)        
      end

      self.options[long] = Option.new(short, long, options)
      self.options[short] = self.options[long]
      self.order << self.options[long]
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
      short = short.to_sym
      long = long.to_sym

      check_args(short, long)

      eval <<-EOF
        def flag_#{long}
          @#{long} = true
        end

        def #{long}?
          return @#{long} || false
        end
      EOF

      self.options[long] = Flag.new(short, long, options)
      self.options[short] = self.options[long]
      self.order << self.options[long]
    end

    def initialize # :nodoc:
      @errors = {}
      @valid = true
    end

    ##
    # Parse the given <tt>args</tt> and set the corresponding instance
    # fields to the given values. If any errors occurred during parsing
    # you can get them from the <tt>Hash</tt> returned by the +errors+ method.
    def parse(args)
      @valid = true
      args = args.split(/\s+/) unless args.kind_of?(Array)
      consumed = []
      if args.member?("--help")
        puts help
        exit 0
      end
      option = nil
    
      args.each do |token|
        case token
        when /^-(-)?\w/
          consumed << token
          param = token.sub(/^-(-)?/, '').sub('-', '_').to_sym
          option = options[param]
          unless option
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
    # Returns a formatted <tt>String</tt> indicating the usage of the parser
    def help
      out = ""
      if banner
        out << "#{banner}\n"
      else
        out << "Usage:\n"
      end

      order.each do |option|
        out << "#{option.usage}\n"
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
      short = short.to_sym
      long = long.to_sym

      if long == :help
        raise IllegalConfiguration.new("You cannot override the built-in 'help' parameter")
      end

      if short == :h
        raise IllegalConfiguration.new("You cannot override the built-in 'h' parameter")
      end

      if self.options.has_key?(long)
        raise IllegalConfiguration.new("You have already defined a parameter/flag for #{long}")
      end

      if self.options.has_key?(short)
        raise IllegalConfiguration.new("You already have a defined parameter/flag for the short key '#{short}")
      end
    end
  end

  class Option # :nodoc:
    attr_accessor :long, :short, :description, :default, :required, :multi

    def initialize(short, long, options)
      @short = short
      @long = long
      @description = options[:desc]
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
  
    def usage
      sprintf('-%-2s --%-10s %s', @short, @long, @description)
    end
  end

  HASHER_REGEX = /^--?\w+/
  ##
  # Turns ARGV into a hash.
  #
  #  my_clip_script -c config.yml # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script command -c config.yml # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script com -c config.yml -d # Clip.hash == { 'c' => 'config.yml' }
  #  my_clip_script -c config.yml --mode optimistic
  #  # Clip.hash == { 'c' => 'config.yml', 'mode' => 'optimistic' }
  def self.hash(argv = ARGV.dup, values = [])
    @hash ||= begin
      argv.shift until argv.first =~ HASHER_REGEX or argv.empty?
      while argv.first =~ HASHER_REGEX and argv.size >= 2 do
        values += [argv.shift.sub(/^--?/, ''), argv.shift]
      end
      Hash[*values]
    end
  end

  ##
  # Clear the cached hash value. Probably only useful for tests, but whatever.
  def Clip.reset_hash!; @hash = nil end
end
