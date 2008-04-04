= clip

== DESCRIPTION:

Yeah yeah yeah. Why in heaven's name do we need yet another
command-line parser? Well, OptionParser is all well and good, but
doesn't grease the skids as much as I'd like. So I wrote this little
library, completely driven by specs.

Cheers!

== FEATURES

You like command-line parsing, but you hate all of the bloat. Why
should you have to create a Hash, then create a parser, then fill
that Hash out then throw the parser away (unless you want to print
out a usage message) and deal with a Hash? Why, for Pete's sake, should
the parser and the parsed values be handled by two different objects?

Well, now they don't...

== SYNOPSIS:

And it goes a little something like this...

  require "rubygems"
  require "clip"

  class MyParser < Clip::Parser
    opt :host, :short => 'h', :desc => 'The host name', :default => 'localhost'
    opt :port, :short => 'p', :desc => 'The port', :default => 8080
    flag :verbose, :short => 'v', :desc => 'Make it chatty'
  end

  parser = MyParser.new
  parser.parse(ARGV)

  if parser.verbose?
    puts parser.host
    puts parser.port
  end

== PROBLEMS:

None so far...

== LICENSE:

(The MIT License)

Copyright (c) 2008 Alex Vollmer

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
