# frozen_string_literal: true
describe MultipartParser do

  context '#xml_content' do
    let(:response) { HTTPI::Response.new 200, { "Content-Type" => content_type }, body }
    subject { MultipartParser.new(response).xml_content }

    context "when response is multipart" do
      let(:content_type) { "multipart/related" }

      context "with a single XML file" do
        let(:body) { "--uuid:61b\r\nContent-Type: application/xop+xml\r\n\r\n"\
                     "<tag>This is the contents</tag>\r\n--uuid:61b--" }
        it { is_expected.to eq "<tag>This is the contents</tag>\r\n" }
      end

      context "with a XML file and file attachment" do
        let(:body) { "--uuid:61b" \
                     "\r\nContent-Type: application/xop+xml"\
                     "\r\n\r\n<tag>This is the contents</tag>\r\n"\
                     "--uuid:61b--\r\nContent-Disposition: attachment"\
                     "\r\n\r\n%PDF-1.4\r\n\r\n"\
                     "--uuid:61b--" }
        it { is_expected.to eq "<tag>This is the contents</tag>\r\n" }
      end
    end

    context "when response is not multipart" do
      let(:content_type) { "text/xml" }
      let(:body) { "<tag>This is the contents</tag>" }

      it { is_expected.to eq "<tag>This is the contents</tag>" }
    end
  end

  context '#mtom_content' do
    let(:response) { HTTPI::Response.new 200, { "Content-Type" => content_type }, body }
    subject { MultipartParser.new(response).mtom_content }

    context "when response is multipart" do
      let(:content_type) { "multipart/related" }

      context "with a single XML file" do
        let(:body) { "--uuid:61b\r\nContent-Type: application/xop+xml\r\n\r\n"\
                     "<tag>This is the contents</tag>\r\n--uuid:61b--" }
        it { is_expected.to eq nil }
      end

      context "with a XML file and file attachment" do
        let(:body) { "--uuid:61b" \
                     "\r\nContent-Type: application/xop+xml"\
                     "\r\n\r\n<tag>This is the contents</tag>\r\n"\
                     "--uuid:61b--\r\nContent-Disposition: attachment"\
                     "\r\n\r\n%PDF-1.4\r\n\r\n"\
                     "--uuid:61b--" }
        it { is_expected.to eq "%PDF-1.4" }
      end

    end

    context "when response is not multipart" do
      let(:content_type) { "text/xml" }
      let(:body) { "<tag>This is the contents</tag>" }

      it { is_expected.to eq nil }
    end
  end
end