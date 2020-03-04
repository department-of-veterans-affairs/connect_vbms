# frozen_string_literal: true

require "spec_helper"

describe VBMS::Service::PagedDocuments do
  let(:client) { new_test_client }
  let(:file_number) { "000669999" }
  let(:page_size) { 20 }
  let(:total_docs) { 101 }
  let(:version_sets) { 2 } # MUST divide page_size evenly.
  let(:small_return_set) { false }

  subject { described_class.new(client: client) }

  def build_documents(max)
    (1..max).map { |x| OpenStruct.new(document_id: "{#{@offset}-#{x}-xxx-nnn-yyy}") }
  end

  def next_response
    @offset ||= 0
    @offset += page_size

    num_docs = (page_size / version_sets)
    num_sets = version_sets
    if @offset > total_docs
      num_docs = total_docs % page_size
      num_sets = 1
      @offset = -1 # trigger ending like VBMS does.
    end
    documents = build_documents(num_docs)

    if small_return_set
      @offset = -1
      documents.pop # make returned set smaller than total_docs
    end

    (1..num_sets).map do
      {
        paging: { :@next_start_index => @offset, :@total_result_count => total_docs },
        documents: documents
      }
    end
  end

  before do
    allow(client).to receive(:send_request) { next_response }
  end

  describe "#call" do
    context "when there are multiple versions" do
      it "returns total documents with pagination metadata" do
        r = subject.call(file_number: file_number)

        expect(r[:pages]).to eq((total_docs / page_size.to_f).ceil(0))
        expect(r[:documents].length).to eq total_docs
        expect(r[:paging][:@total_result_count]).to eq total_docs
      end
    end

    context "where there is a single version set per response" do
      let(:version_sets) { 1 }

      it "returns total documents with pagination metadata" do
        r = subject.call(file_number: file_number)

        expect(r[:pages]).to eq((total_docs / page_size.to_f).ceil(0))
        expect(r[:documents].length).to eq total_docs
        expect(r[:paging][:@total_result_count]).to eq total_docs
      end
    end

    context "when the first page reports more pages than it contains" do
      let(:small_return_set) { true }
      let(:total_docs) { page_size - 1 }

      it "believes the next_offset over the returned document count" do
        r = subject.call(file_number: file_number)

        expect(r[:pages]).to eq(1)
        expect(r[:documents].length).to eq(total_docs - 1)
        expect(r[:paging][:@total_result_count]).to eq total_docs
      end
    end

    context "when the first page contains no sections" do
      it "raises a ClientError" do
        allow(client).to receive(:send_request).and_return []
        expect { subject.call(file_number: file_number) }.to raise_error(VBMS::ClientError)
      end
    end
  end
end
