require 'nori'

module XMLHelper

  def self.convert_to_hash(xml)
    parser.parse(xml)
  end

  # XML to Hash translator
  def self.parser
    @parser ||= Nori.new(convert_tags_to: lambda { |tag| tag.snakecase.to_sym },
                         parser: :nokogiri,
                         strip_namespaces: true)
  end

  # metadata is an array of hashes
  # example => [ { :value => "Joe", :@key => "VeteranFirstName" },
  #              { :value => "Snuffy", :@key => "VeteranLastName" },
  #              { :value => false, :@key => "restricted" } ]
  def self.extract_value(metadata, key)
    metadata.select { |i| i[:@key] == key }[0]
  end

  # when Nori (XML parser) parses the versions in XML document, if it finds multiple versions
  # it creates an array of hashes; if it finds a single version, it creates a hash
  def self.most_recent_version(versions)
    versions.is_a?(Array) ? versions.sort_by { |v| v[:version][:@major].to_i }.last : versions
  end
end
