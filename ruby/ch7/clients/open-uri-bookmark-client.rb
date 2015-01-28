#!/usr/bin/ruby
#open-uri-bookmark-client.rb
require 'rubygems'
require 'rest-open-uri'
require 'uri'
require 'cgi'

# An HTTP-based Ruby client for my social bookmarking service
class BookmarkClient

  def initialize(service_root)
    @service_root = service_root 
  end

  # Turn a Ruby hash into a form-encoded set of key-value pairs.
  def form_encoded(hash)
    encoded = []
    hash.each do |key, value|
      encoded << CGI.escape(key) + '=' + CGI.escape(value)
    end
    return encoded.join('&')
  end

  # Create a new user.
  def new_user(username, password, full_name, email)
    representation = form_encoded({ "user[name]" => username,
                                    "user[password]" => password,
                                    "user[full_name]" => full_name,
                                    "user[email]" => email })      
    puts representation
    begin
      response = open(@service_root + '/users', :method => :post, 
                      :body => representation)
      puts "User #{username} created at #{response.meta['location']}"
    rescue OpenURI::HTTPError => e
      response_code = e.io.status[0].to_i
      if response_code == "409" # Conflict
        puts "Sorry, there's already a user called #{username}."
      else
        raise e
      end
    end
  end

  # Post a new bookmark for the given user.
  def new_bookmark(username, password, uri, short_description)
    representation = form_encoded({ "bookmark[uri]" => uri,
                                    "bookmark[short_description]" => 
                                    short_description })
    begin
      dest = "#{@service_root}/users/#{URI.encode(username)}/bookmarks"
      response = open(dest, :method => :post, :body => representation,
                      :http_basic_authentication => [username, password])
      puts "Bookmark posted to #{response.meta['location']}"
    rescue OpenURI::HTTPError => e
      response_code = e.io.status[0].to_i
      if response_code == 401 # Unauthorized
        puts "It looks like you gave me a bad password."
      elsif response_code == 409 # Conflict
        puts "It looks like you already posted that bookmark."
      else
        raise e
      end
    end    
  end
end

# Main application
command = ARGV.shift
if ARGV.size != 4 || (command != "new-user" && command != "new-bookmark")
  puts "Usage: #{$0} new-user [username] [password] [full name] [email]"
  puts "Usage: #{$0} new-bookmark [username] [password]" +
    " [URI] [short description]"
  exit
end

client = BookmarkClient.new('http://localhost:3000/v1')
if command == "new-user"
  username, password, full_name, email = ARGV
  client.new_user(username, password, full_name, email)
else
  username, password, uri, short_description = ARGV
  client.new_bookmark(username, password, uri, short_description)
end

