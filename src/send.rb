#!/usr/bin/env ruby
require 'pg'
require 'optparse'

require_relative 'vbms'


# log to the DrTurboTax external_activity_log
def db_log(conn, message, request_body, response_body, evaluation_id)
  conn.exec_params(<<-EOM, [message, request_body, response_body, evaluation_id])
INSERT INTO external_activity_logs(message, submitted_data, response_body, evaluation_id)
VALUES ($1, $2, $3, $4)
  EOM
end

class DBLogger
  def initialize(conn)
    @conn = conn
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

def parse(args)
  usage = "Usage: send.rb --pdf <filename> --env <env> --file_number <n> --received_dt <dt> --first_name <name> --middle_name [<name>] --last_name <name> --logfile [<file>] "
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = usage

    opts.on("--pdf <filename>", "PDF file to upload") do |v|
      options[:pdf] = v
    end

    opts.on("--file_number <n>", "File number") do |v|
      options[:file_number] = v
    end

    opts.on("--received_dt <dt>", "Time in iso8601 GMT") do |t|
      options[:received_dt] = t
    end

    opts.on("--first_name <name>", "Veteran first name") do |n|
      options[:first_name] = n
    end

    opts.on("--middle_name [<name>]", "Veteran middle name") do |n|
      options[:middle_name] = n
    end

    opts.on("--last_name <name>", "Veteran last name") do |n|
      options[:last_name] = n
    end

    opts.on("--exam_name <name>", "Name of the exam being sent") do |n|
      options[:exam_name] = n
    end

    opts.on("--env [env]", "Environment to use: test, UAT, ...") do |v|
      options[:env] = v
    end
  end

  parser.parse!

  required_options = [:env, :file_number, :pdf, :received_dt, :first_name, :last_name, :exam_name]
  if !required_options.map{|opt| options.has_key? opt}.all?
    puts "missing keys #{required_options.select{|opt| !options.has_key? opt}}"
    puts parser.help
    exit
  end

  options
end

def upload_doc(options)
  pg_uri = ENV["CONNECT_VBMS_POSTGRES"]
  if pg_uri
    uri = URI.parse(pg_uri)
    logger = DBLogger.new(
      PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    )
  else
    logger = nil
  end

  client = VBMS::Client.from_env_vars(logger: logger, env_name: options[:env])

  request = VBMS::Requests::UploadDocumentWithAssociations.new(
    options[:file_number],
    Time.iso8601(options[:received_dt]),
    options[:first_name],
    options[:middle_name],
    options[:last_name],
    options[:exam_name],
    options[:pdf],
    # Mary Kate Alber told us via email that the doctype should be "C&P Exam",
    # and a getDocumentTypes call shows this as the proper docType
    "356",
    # source
    "VHA_CUI",
    # new_mail
    true,
  )

  puts client.send(request).inspect
end

options = parse(ARGV)
upload_doc(options)
