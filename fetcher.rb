#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'optparse'
require 'uri'

class Fetcher
  def initialize(pds_url, username, password)
    @pds_url = pds_url
    @username = username
    @password = password
    @access_token = nil
  end

  def fetch_and_check_file(key)
    authenticate
    blob_url = get_blob_url(key)
    download_and_check_file(blob_url)
  end

  private

  def authenticate
    uri = URI("#{@pds_url}/xrpc/com.atproto.server.createSession")
    response = Net::HTTP.post(uri, { identifier: @username, password: @password }.to_json, 'Content-Type' => 'application/json')
    data = JSON.parse(response.body)
    @access_token = data['accessJwt']
  end

  def get_blob_url(key)
    uri = URI("#{@pds_url}/xrpc/com.atproto.repo.getRecord")
    params = { repo: @username, collection: 'blue.zio.atfile.upload', rkey: key }
    uri.query = URI.encode_www_form(params)

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end

    record = JSON.parse(response.body)
    did = record['uri'].split('/')[2]
    cid = record['value']['blob']['ref']['$link']

    if @pds_url == "https://zio.blue"
      "#{@pds_url}/blob/#{did}/#{cid}"
    else
      "#{@pds_url}/xrpc/com.atproto.sync.getBlob?did=#{did}&cid=#{cid}"
    end
  end

  def download_and_check_file(blob_url)
    uri = URI(blob_url)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end

    puts "File Information:"
    puts "Size: #{response.body.bytesize} bytes"
    puts "Content-Type: #{response['Content-Type']}"

    # Check if it's an MP3 file
    if response['Content-Type'] == 'audio/mpeg'
      check_mp3_header(response.body)
    else
      puts "\nNot an MP3 file. First 100 bytes of content:"
      puts response.body[0..99].inspect
    end
  end

  def check_mp3_header(content)
    if content.start_with?('ID3')
      puts "ID3 tag found at the beginning of the file"
      tag_size = calculate_id3_size(content[6..9])
      puts "ID3 tag size: #{tag_size} bytes"
    else
      puts "No ID3 tag found at the beginning of the file"
    end

    # Check for MP3 frame sync
    content.each_char.with_index do |byte, index|
      if byte == "\xFF"
        next_byte = content[index + 1]
        if next_byte && next_byte.ord & 0xE0 == 0xE0
          puts "Found MP3 frame sync at offset: #{index}"
          break
        end
      end
    end
  end

  def calculate_id3_size(size_bytes)
    size_bytes.bytes.inject(0) { |sum, byte| (sum << 7) + (byte & 0x7F) }
  end
end

# Default configuration
DEFAULT_CONFIG = {
  server: 'https://bsky.social',
  username: 'handle',
  password: 'app-password',
  key: 'record-key'
}

# Parse command-line arguments
options = DEFAULT_CONFIG.dup
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-u", "--username USERNAME", "PDS username") do |u|
    options[:username] = u
  end

  opts.on("-p", "--password PASSWORD", "PDS password") do |p|
    options[:password] = p
  end

  opts.on("-k", "--key KEY", "Record key") do |k|
    options[:key] = k
  end

  opts.on("-s", "--server SERVER", "PDS server URL") do |s|
    options[:server] = s
  end
end.parse!

# Check for required options
if options[:key].nil?
  puts "Missing required option: key"
  puts "Usage: #{$PROGRAM_NAME} -k <record_key> [-u <username>] [-p <password>] [-s <server>]"
  exit 1
end

# Run the fetcher
fetcher = Fetcher.new(options[:server], options[:username], options[:password])
fetcher.fetch_and_check_file(options[:key])
