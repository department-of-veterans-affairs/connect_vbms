require 'spec_helper'

describe VBMS::Requests::UploadDocumentWithAssociations do
  subject { VBMS::Requests::UploadDocumentWithAssociations.new(
    "123456788",
    Time.now.utc,
    "Joe", "Eagle", "Citizen",
    "UDWA test exam name",
    "/pdf/does/not/exist",
    "doc_type",
    "UDWA test source",
    "UDWA new mail") }

  it "generates valid XML" do
    xml = subject.render_xml
    doc = Nokogiri::XML::Document.parse(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    xsd = Nokogiri::XML::Schema(File.read("spec/soap.xsd"))
    expect(xsd.errors).to eq []
    errors = xsd.validate(Nokogiri::XML(xml))
    expect(errors).to eq []
  end

  it "generates valid Noko XML" do
    xml = subject.render_xml_noko
    File.write("/tmp/x.xml", xml)
    doc = Nokogiri::XML::Document.parse(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    xsd = Nokogiri::XML::Schema(File.read("spec/soap.xsd"))
    expect(xsd.errors).to eq []
    errors = xsd.validate(Nokogiri::XML(xml))
    expect(errors).to eq []
  end

  it "creates equivalent xmls" do
    oldxml = Nokogiri::XML(subject.render_xml)
    newxml = Nokogiri::XML(subject.render_xml_noko)
    expect(oldxml).to be_equivalent_to(newxml).respecting_element_order
  end
end
