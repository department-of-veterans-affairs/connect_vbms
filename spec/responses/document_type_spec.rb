require 'spec_helper'

describe VBMS::Responses::DocumentType do
  describe 'create_from_xml' do
    let(:xml_string) { File.open(fixture_path('requests/get_document_types.xml')).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) { xml.at_xpath('//v4:result', VBMS::XML_NAMESPACES) }

    subject { VBMS::Responses::DocumentType.create_from_xml(doc) }

    specify { expect(subject.type_id).to eq('431') }
    specify { expect(subject.description).to eq('VA 21-4706c Court Appointed Fiduciarys Accounting') }
  end
end
