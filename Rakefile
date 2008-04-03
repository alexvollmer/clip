#!/usr/bin/env ruby

require 'rubygems'
require 'hoe'
require './lib/clip.rb'

Hoe.new('clip', Clip::VERSION) do |p|
  p.developer('Alex Vollmer', nil)
end

require "spec/rake/spectask"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end