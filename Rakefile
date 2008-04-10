#!/usr/bin/env ruby

require 'rubygems'
require 'hoe'
require './lib/clip.rb'

Hoe.new('clip', Clip::VERSION) do |p|
  p.name = 'clip'
  p.developer('Alex Vollmer', 'alex.vollmer@gmail.com')
  p.summary = 'Command-line parsing made short and sweet'
  p.url = 'http://clip.rubyforge.org'
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
      --dry-run \
      --delete \
      #{HERE}/ #{THERE}})
end