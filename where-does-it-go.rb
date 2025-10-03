#! /usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "optparse"

require_relative "lib/manifest"

require "tty-file"

options = {
  force: false,
  skip: false,
  writeToFiles: false,
}

OptionParser.new do |parser|
  parser.on("--[no-]force")          { |value| options[:force]        = value }
  parser.on("--[no-]skip")           { |value| options[:skip]         = value }
  parser.on("--[no-]write-to-files") { |value| options[:writeToFiles] = value }
end.parse!

Manifest.from(ARGF).each do |manifest|
  if options[:writeToFiles]
    TTY::File.create_file(manifest.canonical_path, manifest.to_yaml, force: options[:force], skip: options[:skip])
  else
    $stdout.puts manifest.canonical_path
  end
end
