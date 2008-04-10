#!/usr/bin/env ruby

module Clip
  VERSION = "0.0.1"

  ##
  # Indicates that the parser was incorrectly configured in the
  # block yielded by the +parse+ method.
  class IllegalConfiguration < Exception
  end

  ##
  # Parse arguments (defaults to <tt>ARGV</tt>) with the Parser
  # configured in the given block.
  def self.parse(args=ARGV)
    parser = Parser.new
    raise "Dontcha wanna configure your parser?" unless block_given?
    yield parser
    parser.parse(args)
    parser
  end

  class Parser
    ##
    # Returns any remaining command line arguments that were not parsed
    # because they were neither flags or option/value pairs
    attr_reader :remainder

    ##
    # Declare an optional parameter for your parser. This creates an accessor
    # method matching the <tt>name</tt> parameter. Options that use the '-'
    # character as a word separator are converted to method names using
    # '_'. For example the name 'exclude-files' would create a method named
    # <tt>exclude_files</tt>.
    #
    # When the <tt>:multi</tt> option is enabled, the associated accessor
    # method will return an <tt>Array</tt> instead of a single scalar value.
    # === options
    # Valid options include:
    # * <tt>short</tt>: a single-character version of your parameter
    # * <tt>desc</tt>: a helpful description (used for printing usage)
    # * <tt>default</tt>: a default value to provide if one is not given
    # * <tt>multi</tt>: indicates that mulitple values are okay for this param.
    #
    # Note that specifying the <tt>:multi</tt> option means that the parameter
    # can be specified several times with different values, or that a single
    # comma-separated value can be specified which will then be broken up into
    # separate tokens.
    def optional(name, options={})
      name = name.to_sym
      check_args(name, options)

      eval <<-EOF
        def #{name}=(val)
          @#{name} = val
        end

        def #{name}
          @#{name}
        end
      EOF

      self.options[name] = Option.new(name, options)
      self.order << self.options[name]
      if options[:short]
        self.options[options[:short].to_sym] = self.options[name]
      end
    end

    alias_method :opt, :optional

    ##
    # Declare a required parameter for your parser. If this parameter
    # is not provided in the parsed content, the parser instance
    # will be invalid (i.e. where valid? returns <tt>false</tt>).
    #
    # This method takes the same options as the optional method.
    def required(name, options={})
      optional(name, options.merge({ :required => true }))
    end

    alias_method :req, :required

    ##
    # Declare a parameter as a simple binary flag. This declaration
    # will create a "question" method matching the given <tt>name</tt>.
    # For example, declaring with the name of 'verbose' will create a
    # method your parser called <tt>verbose?</tt>.
    # === options
    # Valid options are:
    # * <tt>short</tt>: A single-character flag accepted for parsing
    # * <tt>desc</tt>: Descriptive text for the flag
    def flag(name, options={})
      name = name.to_sym
      check_args(name, options)

      eval <<-EOF
        def flag_#{name}
          @#{name} = true
        end

        def #{name}?
          return @#{name} || false
        end
      EOF

      self.options[name] = Flag.new(name, options)
      self.order << self.options[name]
      if options[:short]
        self.options[options[:short].to_sym] = self.options[name]
      end
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
      param, value = nil, nil
    
      args.each do |token|
        case token
        when /^-(-)?\w/
          consumed << token
          param = token.sub(/^-(-)?/, '').sub('-', '_').to_sym
          value = nil
        else
          if param
            consumed << token
            value = token
          end
        end

        option = options[param]
        if option
          if (value.nil? && option.kind_of?(Flag)) || value
            option.process(self, value)
          end
        else
          @errors[param] = "Unrecoginzed parameter"
          @valid = false
          next
        end

        unless value.nil?
          param = nil
          value = nil
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
    # Indicates whether or not the parsing process was valid.
    # It only makes sense to call this _after_ calling +parse+.
    def valid?
      @valid
    end

    ##
    # Returns a <tt>Hash</tt> of errors (by parameter) of any errors
    # encountered during parsing.
    def errors
      @errors
    end

    ##
    # Returns a formatted <tt>String</tt> indicating the usage of the parser
    def help
      out = ""
      out << "Usage:\n"
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
    def check_args(name, options={})
      name = name.to_sym
      if name == :help
        raise IllegalConfiguration.new("You cannot override the built-in 'help' parameter")
      end

      if options[:short] == 'h'
        raise IllegalConfiguration.new("You cannot override the built-in 'h' parameter")
      end

      if self.options.has_key?(name)
        raise IllegalConfiguration.new("You have already defined a parameter/flag for #{name}")
      end

      if options[:short] && self.options[options[:short].to_sym]
        raise IllegalConfiguration.new("You already have a defined parameter/flag for the short key '#{options[:short]}")
      end
    end
  end

  class Option # :nodoc:
    attr_accessor :long, :short, :description, :default, :required, :multi

    def initialize(name, options)
      @long = name
      @short = options[:short]
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
      out = sprintf('--%-10s -%-2s %s',
                    @long.to_s.gsub('_', '-').to_sym,
                    @short,
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
    def initialize(name, options)
      @long = name
      @short = options[:short]
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
      sprintf('--%-10s -%-2s %s', @long, @short, @description)
    end
  end
end