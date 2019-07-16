# frozen_string_literal: true

describe VBMS::HTTPError do
  context "body has invalid UTF8" do
    it "replaces invalid UTF8 with blank string" do
      body = "invalid\255"
      error = VBMS::HTTPError.new(500, body)

      expect(error.body).to eq "invalid"
      expect(error.message).to eq "status_code=500, body=invalid, request=nil"
    end
  end
end
