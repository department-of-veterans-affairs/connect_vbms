# frozen_string_literal: true
describe XMLHelper do
  context ".convert_to_hash" do
    let(:xml) { "<tag>This is the contents</tag>" }

    subject { XMLHelper.convert_to_hash(xml) }

    it "returns a hash" do
      expect(subject).to eq(tag: "This is the contents")
    end
  end

  context ".find_hash_by_key" do
    subject { XMLHelper.find_hash_by_key(metadata, "Bar") }

    context "returns hash by key if the key exists" do
      let(:metadata) { [{ :value => "Joe", :@key => "Foo" }, { :value => "Tom", :@key => "Bar" }] }
      it { is_expected.to eq(:value => "Tom", :@key => "Bar") }
    end

    context "returns nil if the key does not exist" do
      let(:metadata) { [{ :value => "Joe", :@key => "Foo" }] }
      it { is_expected.to eq nil }
    end
  end

  context ".most_recent_version" do
    let(:h1) { { version: { :@major => "45" } } }
    let(:h2) { { version: { :@major => "88" } } }

    subject { XMLHelper.most_recent_version(versions) }

    context "when versions is an array" do
      let(:versions) { [h1, h2] }
      it { is_expected.to eq(version: { :@major => "88" }) }
    end

    context "when versions is a hash" do
      let(:versions) { h1 }
      it { is_expected.to eq(version: { :@major => "45" }) }
    end
  end
end
