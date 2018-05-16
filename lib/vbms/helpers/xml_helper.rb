# frozen_string_literal: true
require "nori"

module XMLHelper
  def self.convert_to_hash(xml)
    parser.parse(xml)
  end

  # XML to Hash translator
  def self.parser
    @parser ||= Nori.new(convert_tags_to: ->(tag) { tag.snakecase.to_sym },
                         parser: :nokogiri,
                         strip_namespaces: true)
  end

  # metadata can be an array of hashes
  # example => [ { :value => "Joe", :@key => "VeteranFirstName" },
  #              { :value => "Snuffy", :@key => "VeteranLastName" },
  #              { :value => false, :@key => "restricted" } ]
  #
  # OR
  #
  # metadata can be a hash
  # example => { :value => "Joe", :@key => "VeteranFirstName" }
  def self.find_hash_by_key(metadata, key)
    [metadata].compact.flatten.select { |i| i[:@key] == key }[0]
  end

  # when Nori (XML parser) parses the versions in XML document, if it finds multiple versions
  # it creates an array of hashes; if it finds a single version, it creates a hash
  def self.most_recent_version(versions)
    versions.is_a?(Array) ? sort_versions(versions) : versions
  end

  # If there is only one version we make an array out of it so we can map over it.
  def self.versions_as_array(versions)
    versions.is_a?(Array) ? versions : [versions]
  end

  def self.remove_namespaces(nodes)
    nodes.each { |node| node.namespace = nil }
  end

  def self.sort_versions(versions)
    versions.sort_by { |v| v[:version].try(:[], :@major).to_i }.last
  end
end
