# json-demo.rb
require 'rubygems'
require 'json'

[3, "three"].to_json                 # => "[3,\"three\"]"
JSON.parse('[4, "four"]')            # => [4, "four"]
