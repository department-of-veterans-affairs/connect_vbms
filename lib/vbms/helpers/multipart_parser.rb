class MultipartParser

  def initialize(response)
    @response = response
  end

  def xml_content
    return @response.body unless multipart?
    parts.select { |part| part.header =~ /xml/ }[0].try(:body)
  end

  def attachment_content
    parts.select { |part| part.header =~ /attachment/ }[0].try(:body)
  end

  private

  def multipart?
    !(@response.headers["Content-Type"] =~ /^multipart/im).nil?
  end

  def parts
    parts = split_based_on_boundary
    # each part will contain a header info and a body which is separated by r\n\r\n
    parts.map { |part|
      doc_parts = part.split(/\r\n\r\n/)
      OpenStruct.new(header: doc_parts[0], body: doc_parts[1])
    }
  end

  def find_boundary
    # if it is a multipart, the boundary is at location zero
    @response.body.split("\r\n")[0].strip
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