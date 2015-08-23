require 'spec_helper'

describe VBMS::Requests::ListDocuments do
  let (:list_documents_response_xml) { fixture_path('list_documents_response.xml') }

  it "parses received dates correctly" do
    request = VBMS::Requests::ListDocuments.new('')
    xml = File.read(list_documents_response_xml)
    doc = Nokogiri::XML(xml)
    vbmsDocs = request.handle_response(doc)

    expect(vbmsDocs[0].received_at).to eq(Date.parse('2015-08-03-04:00'))
    expect(vbmsDocs[1].received_at).to eq(Date.parse('2015-08-07-04:00'))
  end
end
