#!/usr/bin/ruby -w
# activeresource-notebook-manipulation.rb

require 'activesupport/lib/active_support'
require 'activeresource/lib/active_resource'

# Define a model for the objects exposed by the site
class Note < ActiveResource::Base
  self.site = 'http://localhost:3000/'
end

def show_notes
  notes = Note.find :all                 # GET /notes.xml
  puts "I see #{notes.size} note(s):"
  notes.each do |note|
    puts " #{note.date}: #{note.body}"
  end
end

new_note = Note.new(:date => Time.now, :body => "A test note")
new_note.save                            # POST /notes.xml

new_note.body = "This note has been modified."
new_note.save                            # PUT /notes/{id}.xml

show_notes

new_note.destroy                         # DELETE /notes/{id}.xml

puts
show_notes
