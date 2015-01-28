#!/usr/bin/python
# activeresource-notebook-manipulation.py

from elementtree.ElementTree import Element, SubElement, tostring
from elementtree import ElementTree
import httplib2
import time

BASE = "http://localhost:3000/"
client = httplib2.Http(".cache")

def showNotes():
    headers, xml = client.request(BASE + "notes.xml")
    doc = ElementTree.fromstring(xml)
    for note in doc.findall('note'):
        print "%s: %s" % (note.find('date').text, note.find('body').text)

newNote = Element("note")
date = SubElement(newNote, "date")
date.attrib['type'] = "date"
date.text = time.strftime("%Y-%m-%d", time.localtime())
body = SubElement(newNote, "body")
body.text = "A test note"
 
headers, ignore = client.request(BASE + "notes.xml", "POST",
                                 body= tostring(newNote),
                                 headers={'content-type' : 'application/xml'})
newURI = headers['location']

modifiedBody = Element("note")
body = SubElement(modifiedBody, "body")
body.text = "This note has been modified"

client.request(newURI, "PUT",
               body=tostring(modifiedBody),
               headers={'content-type' : 'application/xml'})

showNotes()

client.request(newURI, "DELETE")

print
showNotes()
