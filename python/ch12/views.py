import datetime
from bookmarks.models import Bookmark
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core import serializers
from django.http import *
from django.shortcuts import get_object_or_404

# Use a third-party module to help handle dates,
# See http://labix.org/python-dateutil
import dateutil.parser 
from dateutil.tz import tzlocal, tzutc

def bookmark_list(request, username):
    u = get_object_or_404(User, username=username)
    
    # Build a dynmaic dict of lookup parameters using the 
    # If-Modified-Since header if it's given.
    lookup = dict(user=u, public=True)
    lm = request.META.get("HTTP_IF_MODIFIED_SINCE", None)
    if lm:
        try:
            lm = dateutil.parser.parse(lm)
        except ValueError:
            lm = None # Ignore invalid dates
        else:
            lookup['timestamp__gt'] = lm.astimezone(tzlocal())

    # Look up the bookmarks.
    marks = Bookmark.objects.filter(**lookup)
    
    # If we got If-Modified-Since but there aren't any bookmarks, 
    # return a 304 (not modified) response.
    if lm and marks.count() == 0:
        return HttpResponseNotModified()
    
    # Otherwise return the serialized data...
    json = serializers.serialize("json", marks)
    import sys
    print >> sys.stderr, marks
    response = HttpResponse(json, mimetype="application/json")
    
    # ... with the appropriate Last-Modified header.
    now = datetime.datetime.now(tzutc())
    response["Last-Modified"] = now.strftime("%a, %d %b %Y %H:%M:%S GMT")
    return response

class BookmarkDetail:

    def __call__(self, request, username, bookmark_url):
        self.request = request
        self.bookmark_url = bookmark_url
        
        # Look up the user and throw a 404 if it doesn't exist
        self.user = get_object_or_404(User, username=username)
        
        # Try to locate a handler method.
        try:
            callback = getattr(self, "do_%s" % request.method)
        except AttributeError:
            # This class doesn't implement this HTTP method, so return a
            # 405 (method not allowed) response with the allowed methods.
            allowed_methods = [m[3:] for m in dir(self) if m.startswith("do_")]
            return HttpResponseNotAllowed(allowed_methods)
            
        # Check and store HTTP basic authentication, even for methods that
        # don't require authorization.
        self.authenticate()
        
        # Call the looked-up method
        return callback()
        
    def authenticate(self):
        # Pull the auth info out of the Authorization: header
        auth_info = self.request.META.get("HTTP_AUTHORIZATION", None)
        if auth_info and auth_info.startswith("Basic "):
            basic_info = auth_info.split(" ", 1)[1]
            u, p = basic_info.decode("base64").split(":")
            
            # Authenticate against the User database. This will set
            # authenticated_user to None if authentication fails.
            self.authenticated_user = authenticate(username=u, password=p)
        else:
            self.authenticated_user = None
    
    def forbidden(self):
        response = HttpResponseForbidden()
        response["WWW-Authenticate"] = 'Basic realm="Bookmarks"'
        return response
                
    def do_GET(self):
        # Look up the bookmark (possibly throwing a 404)
        bookmark = get_object_or_404(Bookmark, 
            user=self.user, 
            url=self.bookmark_url
        )

        # Check privacy
        if bookmark.public == False and self.user != self.authenticated_user:
            return self.forbidden()

        json = serializers.serialize("json", [bookmark])
        return HttpResponse(json, mimetype="application/json")
            
    def do_PUT(self):
        # Check that the user in the URL matches the authorization
        if self.user != self.authenticated_user:
            return self.forbidden()
        
        # Deserialize the object from the request. Serializers work the lists,
        # but we're only expecting one here. Any errors and we return a 400.
        try:
            deserialized = serializers.deserialize("json", self.request.raw_post_data)
            put_bookmark = list(deserialized)[0].object
        except (ValueError, TypeError, IndexError):
            response = HttpResponse()
            response.status_code = 400
            return response
            
        # Lookup or create a bookmark, then update it
        bookmark, created = Bookmark.objects.get_or_create(
            user = self.user,
            url = self.bookmark_url,
        )
        for field in ["short_description", "long_description", "public", "timestamp"]:
            new_val = getattr(put_bookmark, field, None)
            if new_val:
                setattr(bookmark, field, new_val)
        bookmark.save()
        
        # Return the serialized object, with either a 200 (OK) or a 201
        # (Created) status code.
        json = serializers.serialize("json", [bookmark])
        response = HttpResponse(json, mimetype="application/json")
        if created:
            response.status_code = 201
            response["Location"] = "/users/%s/%s" % (self.user.username, bookmark.url)
        return response
        
    def do_DELETE(self):
        # Check authorization
        if self.user != self.authenticated_user:
            return self.forbidden()

        # Look up the bookmark...
        bookmark = get_object_or_404(Bookmark, 
            user=self.user, 
            url=self.bookmark_url
        )

        # ... and delete it.
        bookmark.delete()

        # Return a 204 ("no content")
        response = HttpResponse()
        response.status_code = 204
        return response

def tag_list(request):
    pass
    
def tag_detail(request):
    pass
    
