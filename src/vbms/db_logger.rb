module VBMS
  class DBLogger
    def initialize(pg_uri)
      uri = URI.parse(pg_uri)
      @conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    end

    def log(event, data)
      if event == :decrypted_message
        message = "connect_vbms decrypted response"
        request_body = ""
        response_body = data[:decrypted_data]
        evaluation_id = data[:request].file_number
      elsif event == :request
        message = "connect_vbms status #{data[:response_code]}"
        request_body = data[:request_body]
        response_body = data[:response_body]
        evaluation_id = data[:request].file_number
      else
        raise NotImplementedError.new(event)
      end

      @conn.exec_params(<<-EOM, [message, request_body, response_body, evaluation_id])
  INSERT INTO external_activity_logs(message, submitted_data, response_body, evaluation_id)
  VALUES ($1, $2, $3, $4)
  EOM
    end
  end
end
