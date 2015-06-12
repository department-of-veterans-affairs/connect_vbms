#!/usr/bin/env ruby
require 'pg'
require 'optparse'

require_relative 'vbms'

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

def env_path(env_dir, env_var_name)
  value = ENV[env_var_name]
  if value.nil?
    return nil
  else
    return File.join(env_dir, value)
  end
end

def init_logger
  if pg_uri = ENV["CONNECT_VBMS_POSTGRES"]
    VBMS::DBLogger.new(pg_uri)
  else
    nil
  end
end

def upload_doc(options)
  logger = init_logger

  env_dir = File.join(ENV["CONNECT_VBMS_ENV_DIR"], options[:env])
  client = VBMS::Client.new(
    ENV["CONNECT_VBMS_URL"],
    env_path(env_dir, "CONNECT_VBMS_KEYFILE"),
    env_path(env_dir, "CONNECT_VBMS_SAML"),
    env_path(env_dir, "CONNECT_VBMS_KEY"),
    ENV["CONNECT_VBMS_KEYPASS"],
    env_path(env_dir, "CONNECT_VBMS_CACERT"),
    env_path(env_dir, "CONNECT_VBMS_CERT"),
    logger,
  )

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
