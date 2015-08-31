require 'spec_helper'

describe VBMS::Requests::FetchDocumentById do
  subject { VBMS::Requests::FetchDocumentById.new("a document id") }

  it "generates valid XML" do
    xml = subject.render_xml
    doc = Nokogiri::XML::Document.parse(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    xsd = Nokogiri::XML::Schema(File.read("spec/soap.xsd"))
    expect(xsd.errors).to eq []
    errors = xsd.validate(Nokogiri::XML(xml))
    expect(errors).to eq []
  end
end
