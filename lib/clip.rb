#!/usr/bin/env ruby

module Clip
  VERSION = "0.0.1"

  # The base class for command-line parser. Specific parsers should extend this class
  # and provide simple attribute methods matching the options to be parsed
  class Parser
    class << self
      ##
      # Declare an optional parameter for your parser. This creates an accessor
      # method matching the <tt>name</tt> parameter.
      # === options
      # Valid options include:
      # * <tt>short</tt>: a single-character version of your parameter
      # * <tt>desc</tt>: a helpful description (used for printing usage)
      # * <tt>default</tt>: a default value to provide if one is not given
      def opt(name, options={})
        attr_accessor name.to_sym
        if options[:short]
          alias_method options[:short].to_sym, name.to_sym
          alias_method "#{options[:short]}=".to_sym, "#{name}=".to_sym
        end
    
        self.options << Option.new(name, options)
      end

      ##
      # Declare a required parameter for your parser. If this parameter
      # is not provided in the parsed content, the parser instance
      # will be invalid (i.e. where +valid?+ return <tt>false</tt>).
      def req(name, options={})
        attr_accessor name.to_sym
        if options[:short]
          alias_method options[:short].to_sym, name.to_sym
          alias_method "#{options[:short]}=".to_sym, "#{name}=".to_sym
        end

        self.options << Option.new(name, options.merge({ :required => true }))
      end

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
            return @#{name}
          end
        EOF

        if options[:short]
          class_eval <<-EOF
            alias_method :#{options[:short]}?, :#{name}?
            alias_method :flag_#{options[:short]}, :flag_#{name}
          EOF
        end

        self.options << Option.new(name, options.merge({ :required => false, :default => nil }))
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
      param, value = nil, nil
    
      args.each do |token|
        case token
        when /^-(-)?\w/
          param = token.sub(/^-(-)?/, '').sub('-', '_')
          value = nil
        else
          value = token
        end
      
        unless self.respond_to?(param.to_sym) or self.respond_to?("#{param}?".to_sym)
          @errors[param.to_sym] = "Unrecoginzed parameter"
          @valid = false
          next
        end

        if self.respond_to?("#{param}=")
          self.send("#{param}=".to_sym, value.nil? ? true : value)
        else
          # FIXME: what happens when somebody sends us a value?
          self.send("flag_#{param}")
        end
      end
    
      self.class.options.each do |option|
        if option.has_default? and self.send(option.long.to_sym).nil?
          self.send("#{option.long}=".to_sym, option.default)
        end
      end
    
      self.class.options.find_all { |e| e.required? }.each do |required|
        unless self.send(required.long.to_sym)
          @valid = false
          @errors[required.long.to_sym] = "Missing required parameter"
          # raise MissingArgument.new("Missing required arg, '#{required.long}'")
        end
      end
    rescue UnrecognizedOption
      @valid = false
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
  
    def help(*args)
      if args
        out = args.shift
      else
        out = STDOUT
      end
    
      out << "Usage:\n"
      self.class.options.each do |option|
        out << "#{option.usage}\n"
      end
    end

    private
    def self.inherited(sub)
      sub.class_eval <<-EOF
        def self.options
          @@options ||= []
        end
      EOF
    end    
  end

  private
  class Option
    attr_accessor :long, :short, :description, :default, :required

    def initialize(name, options)
      @long = name
      @short = options[:short]
      @description = options[:desc]
      @default = options[:default]
      @required = options[:required]
    end

    def required?
      @required == true
    end

    def has_default?
      not @default.nil?
    end
  
    def usage
      out = StringIO.new
      out << "--#{@long}"
      out << " -#{@short}"
      out << " #{@description}" if @description
      out << " (defaults to '#{@default}')" if @default
      out << " REQUIRED" if @required
      out.string
    end
  end

end