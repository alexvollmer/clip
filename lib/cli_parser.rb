#!/usr/bin/env ruby

# Signals a command-line option that is not recognized by the +CliParser+
# implementation.
class UnrecognizedOption < StandardError
end

# Signals that a required command-line argument was not given when options were parsed
class MissingArgument < StandardError
end

# The base class for command-line parser. Specific parsers should extend this class
# and provide simple attribute methods matching the options to be parsed
class CliParser
  def self.opt(name, options={})
    attr_accessor name.to_sym
    if options[:short]
      alias_method options[:short].to_sym, name.to_sym
      alias_method "#{options[:short]}=".to_sym, "#{name}=".to_sym
    end
    
    self.options << Option.new(name, options[:short], options[:desc], options[:default], options[:required])
  end
  
  def parse(args)
    args = args.split(/\s+/) unless args.kind_of?(Array)
    flag, value = nil, nil
    
    args.each do |token|
      case token
      when /^-(-)?\w/
        flag = token.sub(/^-(-)?/, '').sub('-', '_')
        value = nil
      else
        value = token
      end
      
      raise UnrecognizedOption.new("Unknown option '#{flag}'") unless self.respond_to?(flag.to_sym)
      self.send("#{flag}=".to_sym, value.nil? ? true : value)
    end
    
    self.class.options.each do |option|
      if option.has_default? and self.send(option.long.to_sym).nil?
        self.send("#{option.long}=".to_sym, option.default)
      end
    end
    
    self.class.options.find_all { |e| e.required? }.each do |required|
      unless self.send(required.long.to_sym)
        raise MissingArgument.new("Missing required arg, '#{required.long}'")
      end
    end
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
  
  def self.inherited(sub)
    sub.class_eval <<-EOF
      def self.options
        @@options ||= []
      end
    EOF
  end    
end

class Option
  attr_accessor :long, :short, :description, :default, :required
  
  def initialize(long, short, description, default, required)
    @long, @short, @description, @default, @required = long, short, description, default, required
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
