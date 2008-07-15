= clip

== DESCRIPTION:

Yeah yeah yeah. Why in heaven's name do we need yet another
command-line parser? Well, OptionParser is all well and good[1], but
doesn't grease the skids as much as I'd like. Simple things should be
dead simple (1 LOC), and more flexibility is there if you need it.

Cheers!

== FEATURES

You like command-line parsing, but you hate all of the bloat. Why
should you have to create a Hash, then create a parser, fill the Hash
out then throw the parser away (unless you want to print out a usage
message) and deal with a Hash? Why, for Pete's sake, should the parser
and the parsed values be handled by two different objects?

Introducing Clip...

== SYNOPSIS:

And it goes a little something like this...

  require "rubygems"
  require "clip"

  options = Clip do |p|
    p.optional 's', 'server', :desc => 'The server name', :default => 'localhost'
    p.optional 'p', 'port', :desc => 'The port', :default => 8080 do |v|
      v.to_i # always deal with integers
    end
    p.required 'f', 'files', :multi => true, :desc => 'Files to send'
    p.flag     'v', 'verbose', :desc => 'Make it chatty'
  end

  if options.valid?
    if options.verbose?
      puts options.host
      puts options.port
      puts 'files:'
      options.files.each do |f|
        puts "\t#{f}"
      end
    end
  else
    # print error message(s) and usage
    $stderr.puts options.to_s
  end

The names of the options and flags that you declare in the block are accessible
as methods on the returned object, reducing the amount of objects you have to
deal with when you're parsing command-line parameters.

You can optionally process parsed arguments by passing a block to the
<tt>required</tt> or <tt>optional</tt> methods which will set the value of the
option to the result of the block. The block will receive the parsed value and
should return whatever transformed value that is appropriate to your use case.

Simply invoking the <tt>to_s</tt> method on a parser instance will dump both the
correct usage and any errors encountered during parsing. No need for you to manage
the state of what's required and what isn't by yourself. Also, '--help' and '-h'
will automatically trigger Clip to dump out usage and exit.

Sometimes you have additional arguments you need to process that don't require
a named option or flag. Whatever remains on the command line that doesn't fit
either a flag or an option/value pair will be made available via the
<tt>remainder</tt> method of the returned object.

Sometimes even passing a block is overkill. Say you want to grab just
a hash from a set of name/value argument pairs provided:

  $ my_clip_script subcommand -c config.yml # Allows:
  Clip.hash == { 'c' => 'config.yml' }

  $ my_clip_script -c config.yml --mode optimistic # Allows:
   Clip.hash == { 'c' => 'config.yml', 'mode' => 'optimistic' }

----------------------------------------

[1] - Not really.

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
