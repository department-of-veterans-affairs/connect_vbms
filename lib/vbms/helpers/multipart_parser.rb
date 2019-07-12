# frozen_string_literal: true
class MultipartParser
  def initialize(response)
    @response = response
  end

  def xml_content
    return @response.body unless multipart?
    parts.select { |part| part.header =~ /xml/ }[0].try(:body)
  end

  def mtom_content
    parts.select { |part| part.header =~ /attachment/ }[0].try(:body)
  end

  private

  def multipart?
    !(@response.headers["Content-Type"] =~ /^multipart/im).nil?
  end

  def parts
    parts = split_based_on_boundary
    parts.map do |part|
      # the header and the body is always separated by r\n\r\n
      header = part.split(/\r\n\r\n/)[0]
      # remove the header from the part
      part.slice!(header + "\r\n\r\n")
      OpenStruct.new(header: header, body: part)
    end
  end

  def find_boundary
    # if it is a multipart, the boundary is at location zero
    lines = @response.body.split("\r\n")
    lines.shift while lines[0] == ""
    lines[0].strip
  end

  def split_based_on_boundary
    # split the body based on the boundary
    parts = @response.body.split(find_boundary)
    # the first part will always be an empty string so remove it
    parts.shift
    # the last part will be the "--" so remove it
    parts.pop
    parts
  end
end
