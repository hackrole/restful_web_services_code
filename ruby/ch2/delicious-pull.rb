#!/usr/bin/ruby -w
# delicious-pull.rb
require 'open-uri'
require 'rexml/parsers/pullparser'

def print_my_recent_bookmarks(username, password)
  # Make an HTTPS request and read the entity-body as an XML document.
  xml = open('https://api.del.icio.us/v1/posts/recent',
             :http_basic_authentication => [username, password])

  # Feed the XML entity-body into a pull parser
  parser = REXML::Parsers::PullParser.new(xml)

  # Until there are no more events to pull...
  while parser.has_next?
    # ...pull the next event.
    tag = parser.pull    
    # If it's a 'post' tag...
    if tag.start_element?
      if tag[0] == 'post'       
        # Print information about the bookmark.
        attrs = tag[1]
        puts "#{attrs['description']}: #{attrs['href']}"
      end
    end
  end
end

# Main program.
username, password = ARGV
unless username and password
  puts "Usage: #{$0} [USERNAME] [PASSWORD]"  
  exit
end
print_my_recent_bookmarks(username, password)
