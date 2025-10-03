#! /usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "forwardable"
require "json"
require "pathname"
require "yaml"

require_relative "infrastructure"

require "contracts"

# class Psych::Visitors::YAMLTree
#   def visit_Symbol(symbol) = visit_String(String(symbol))
# end

module SerializeSymbolsAsStrings
  class Serializer < ::Psych::Visitors::YAMLTree
    def visit_Symbol(symbol) = visit_String(String(symbol))
  end

  refine Object do
    def to_yaml = Serializer.create.tap { |serializer| serializer << self }.tree.yaml
  end
end

class Manifest
  extend Forwardable
  include Contracts::Core
  include Contracts::Builtin
  using SerializeSymbolsAsStrings

  def_delegator :@document, :to_h
  def_delegator :@document, :to_hash
  def_delegator :@document, :deconstruct_keys
  def_delegator :@document, :[]
  def_delegator :@document, :fetch

  BASEDIR = Pathname("manifests")

  def to_yaml = @document.to_yaml

  def self.namespacing_rules
    @namespacing_rules ||= (Pathname(__FILE__).dirname + "namespacing-rules.yaml").then do |rules|
      YAML.load(rules.read, symbolize_names: true).fetch(:rules)
    end
  end

  def namespaced?
    self => { kind: }
    apiGroupVersion => { apiGroup: }
    rule = self.class.namespacing_rules.find do |rule|
      rule in { apiGroup: apiGroup, kind: kind }
    end
    rule&.fetch(:namespaced)
  end

  Contract String => self
  def self.from(document)
    YAML.load(document, symbolize_names: true).then do |document|
      new(**document)
    end
  end

  Contract Enumerable => ArrayOf[self]
  def self.from(stream)
    YAML.load_stream(stream, symbolize_names: true).map do |document|
      new(**document)
    end
  end

  def initialize(**document)
    @document = document
  end

  Contract None => { apiGroup: Maybe[String], apiGroupVersion: String, apiVersion: String }
  def apiGroupVersion
    self => { apiVersion: }
    Patterns::API_GROUP_VERSION.match(apiVersion) => { apiGroup:, apiGroupVersion:, apiVersion: }
    { apiGroup:, apiGroupVersion:, apiVersion: }
  end

  Contract None => Maybe[String]
  def namespace
    case self
      in { metadata: { namespace: nil } } then (namespaced? in false | nil) ? nil : "default"
      in { metadata: { namespace:     } } then (namespaced? in true  | nil) ? namespace : nil
    else namespaced? ? "default" : nil
    end
  end

  Contract None => Pathname
  def canonical_path
    self => { kind:, metadata: { name: } }
    [BASEDIR, namespace, "resources", kind, "#{name}.yaml"].compact.reduce(&:+)
  end

  module Patterns
    API_GROUP_VERSION = %r{^(?<apiGroupVersion>((?<apiGroup>[^/]+)/)?(?<apiVersion>.+))$}
  end
end
