#!/usr/bin/env ruby

# TODO:
# Time for a major architectural change. The self.class.options variable
# now becomes a Hash. As we declare flags, optionals and requireds we
# add them to this hash (keyed by both long and short symbols). Each
# Option has a block associated with it to be invoked as its parameter
# is invoked.
#
# The main parsing loop is changed to one that simply converts a flat
# command line to a hash of parameters => values. We then loop through
# the hash and apply each key/value pair to the Option blocks.
#
# Still not quite sure how we deal with required options that are missing.
# Maybe we dynamically build the +valid?+ method out.
module Clip
  VERSION = "0.0.1"

  # The base class for command-line parser. Specific parsers should extend
  # this class and declare how the command-line should be parsed with
  # the +optional+, +required+ and +flag+ class methods.
  class Parser
    class << self
      ##
      # Declare an optional parameter for your parser. This creates an accessor
      # method matching the <tt>name</tt> parameter. Options that use the '-'
      # character as a word separator are converted to method names using
      # '_'. For example the name 'exclude-files' would create a method named
      # <tt>exclude_files</tt>.
      # === options
      # Valid options include:
      # * <tt>short</tt>: a single-character version of your parameter
      # * <tt>desc</tt>: a helpful description (used for printing usage)
      # * <tt>default</tt>: a default value to provide if one is not given
      def optional(name, options={})
        name = name.to_sym
        attr_accessor name
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
      # will be invalid (i.e. where +valid?+ return <tt>false</tt>).
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
        class_eval <<-EOF
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
    end
    
    def initialize
      @errors = {}
    end

    ##
    # Parse the given <tt>args</tt> and set the corresponding instance
    # fields to the given values. If any errors occurred during parsing
    # you can get them from the <tt>Hash</tt> returned by the +errors+ method.
    def parse(args)
      @valid = true
      args = args.split(/\s+/) unless args.kind_of?(Array)
      if args.member?("--help")
        puts help
        exit 0
      end
      param, value = nil, nil
    
      args.each do |token|
        case token
        when /^-(-)?\w/
          param = token.sub(/^-(-)?/, '').sub('-', '_').to_sym
          value = nil
        else
          value = token
        end

        option = self.class.options[param]
        if option
          if (value.nil? && option.kind_of?(Flag)) || value
            option.process(self, value)
          end
        else
          @errors[param] = "Unrecoginzed parameter"
          @valid = false
          next
        end
      end

      # Find required options that are missing arguments
      self.class.options.each do |param, opt|
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
      self.class.order.each do |option|
        out << "#{option.usage}\n"
      end
      out
    end

    private
    def self.inherited(sub)
      sub.class_eval <<-EOF
        def self.options          
          (@@options ||= {})
        end

        def self.order
          (@@order ||= [])
        end
      EOF
    end    
  end

  class Option
    attr_accessor :long, :short, :description, :default, :required

    def initialize(name, options)
      @long = name
      @short = options[:short]
      @description = options[:desc]
      @default = options[:default]
      @required = options[:required]
    end

    def process(parser, value)
      parser.send("#{@long}=".to_sym, value)
    end

    def required?
      @required == true
    end

    def has_default?
      not @default.nil?
    end
  
    def usage
      out = sprintf('--%-10s -%-2s %s', @long, @short, @description)
      out << " (defaults to '#{@default}')" if @default
      out << " REQUIRED" if @required
      out
    end
  end

  class Flag
    
    attr_accessor :long, :short, :description

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