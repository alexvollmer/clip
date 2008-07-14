Gem::Specification.new do |s|
  s.name = %q{clip}
  s.version = "0.0.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alex Vollmer"]
  s.date = %q{2008-07-14}
  s.description = %q{You like command-line parsing, but you hate all of the bloat. Why should you have to create a Hash, then create a parser, fill the Hash out then throw the parser away (unless you want to print out a usage message) and deal with a Hash? Why, for Pete's sake, should the parser and the parsed values be handled by two different objects?}
  s.email = ["alex.vollmer@gmail.com"]
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = ["History.txt", "README.txt", "lib/clip.rb", "spec/clip_spec.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://clip.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{clip}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Command-line parsing made short and sweet}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<hoe>, [">= 1.6.0"])
    else
      s.add_dependency(%q<hoe>, [">= 1.6.0"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.6.0"])
  end
end
