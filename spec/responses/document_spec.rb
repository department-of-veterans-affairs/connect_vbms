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

  describe 'serialization' do
    let(:attrs) do
      { document_id: '{9E364101-AFDD-49A7-A11F-602CCF2E5DB5}', filename: 'tmp20150506-94244-6zotzp', 
        doc_type: '356', source: 'VHA_CUI', mime_type: 'text/plan', received_at: Time.now }
    end
    subject { VBMS::Responses::Document.new(attrs) }

    it 'should respond to to_h' do
      expect(subject.to_h).to be_a(Hash)
      expect(subject.to_h).to include(attrs)
    end

    it 'should respond to to_s' do
      expect(subject.to_s).to be_a(String)
    end

    it 'should respond to inspect' do
      expect(subject.inspect).to eq(subject.to_s)
    end
  end
end
