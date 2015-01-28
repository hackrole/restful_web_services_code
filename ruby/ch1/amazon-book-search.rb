#!/usr/bin/ruby -w
# amazon-book-search.rb
require 'amazon/search'

if ARGV.size != 2
  puts "Usage: #{$0} [Amazon Web Services AccessKey ID] [text to search for]"
  exit
end
access_key, search_request = ARGV

req = Amazon::Search::Request.new(access_key)
# For every book in the search results...
req.keyword_search(search_request, 'books', Amazon::Search::LIGHT) do |book|
  # Print the book's name and the list of authors.
  puts %{"#{book.product_name}" by #{book.authors.join(', ')}}
end
