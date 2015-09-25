require 'spec_helper'

describe VBMS::Responses::Document do
  describe 'create_from_xml' do
    let(:xml_string) { File.open(fixture_path('requests/fetch_document.xml')).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) { xml.at_xpath('//v4:document', VBMS::XML_NAMESPACES) }

    subject { VBMS::Responses::Document.create_from_xml(doc) }

    specify { expect(subject.document_id).to eq('{9E364101-AFDD-49A7-A11F-602CCF2E5DB5}') }
    specify { expect(subject.filename).to eq('tmp20150506-94244-6zotzp') }
    specify { expect(subject.doc_type).to eq('356') }
    specify { expect(subject.source).to eq('VHA_CUI') }
    specify { expect(subject.mime_type).to eq('text/plain') }
    specify { expect(subject.received_at).to eq(Date.parse('2015-05-06')) }
  end
end
