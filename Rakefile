#!/usr/bin/env ruby

require 'rubygems'
require 'hoe'
require './lib/clip.rb'

Hoe.new('clip', Clip::VERSION) do |p|
  p.name = 'clip'
  p.developer('Alex Vollmer', 'alex.vollmer@gmail.com')
  p.description = p.paragraphs_of('README.txt', 5..5).join("\n\n")
  p.summary = 'Command-line parsing made short and sweet'
  p.url = 'http://clip.rubyforge.org'
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.remote_rdoc_dir = ''
end

require "spec/rake/spectask"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

HERE = "web"
THERE = "avollmer@clip.rubyforge.org:/var/www/gforge-projects/clip"

desc "Sync web files here"
task :sync_here do
  puts %x(rsync \
      --verbose \
      --recursive \
      #{THERE}/ #{HERE})
end

desc "Sync web files there"
task :sync_there do
  puts %x(rsync \
      --verbose \
      --recursive \
      --delete \
      #{HERE}/ #{THERE}})
end

desc "Code statistics"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(['lib'], ['spec']).to_s
end

task :default => :spec
