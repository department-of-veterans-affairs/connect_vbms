module VBMS
  module Responses
    class DocumentType
      attr_accessor :type_id, :description
  
      def initialize(type_id: nil, description: nil)
        self.type_id = type_id
        self.description = description
      end
  
      def self.create_from_xml(el)
        new(type_id: el['id'],
            description: el['description'])
      end
    end
  end
end
