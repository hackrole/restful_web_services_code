# app/controllers/application.rb
require 'digest/sha1'
require 'digest/md5'
require 'rubygems'
require 'atom/feed'

class ApplicationController < ActionController::Base

  # By default, show 50 bookmarks at a time.
  @@default_limit = 50

  ## Common actions

  # This action takes a list of SQL conditions, adds some additional
  # conditions like a date filter, and renders an appropriate list of
  # bookmarks. It's used by BookmarksController, RecentController,
  # and TagsController.
  def show_bookmarks(conditions, title, feed_uri, user=nil, tag=nil)
    errors = []

    # Make sure the specified limit is valid. If no limit is specified,
    # use the default.
    if params[:limit] && params[:limit].to_i < 0
      errors << "limit must be >=0"
    end
    params[:limit] ||= @@default_limit
    params.delete(:limit) if params[:limit] == 0  # 0 means "no limit"

    # If a date filter was specified, make sure it's a valid date.
    if params[:date]
      begin        
        params[:date] = Date.parse(params[:date])
      rescue ArgumentError
        errors << "incorrect date format"
      end
    end

    if errors.empty?
      conditions ||= [""]
      
      # Add a restriction by date if neccessary.
      if params[:date]
        conditions[0] << " AND " unless conditions[0].empty?
        conditions[0] << "timestamp >= ? AND timestamp < ?"
        conditions << params[:date]
        conditions << params[:date] + 1
      end

      # Restrict the list to bookmarks visible to the authenticated user.
      Bookmark.only_visible_to!(conditions, @authenticated_user)

      # Find a set of bookmarks that matches the given conditions.
      bookmarks = Bookmark.custom_find(conditions, tag, params[:limit])
      
      # Render the bookmarks however the client requested.
      render_bookmarks(bookmarks, title, feed_uri, user)
    else
      render :text => errors.join("\n"), :status => "400 Bad Request"
    end
  end
##
  # This method renders a list of bookmarks as a view in RSS, Atom, or
  # ActiveRecord XML format. It's called by show_bookmarks
  # above, which is used by three controllers. It's also used
  # separately by UriController and BookmarksController.
  # 
  # This view method supports conditional HTTP GET.
  def render_bookmarks(bookmarks, title, feed_uri, user, except=[])
    # Figure out a current value for the Last-Modified header.
    if bookmarks.empty?
      last_modified = nil
    else
      # Last-Modified is the most recent timestamp in the bookmark list.
      most_recent_bookmark = bookmarks.max do |b1,b2|
        b1.timestamp <=> b2.timestamp
      end
      last_modified = most_recent_bookmark.timestamp
    end
    
    # If the bookmark list has been modified since it was last requested...
    render_not_modified_or(last_modified) do
      respond_to do |format|
        # If the client requested XML, serialize the ActiveRecord
        # objects to XML. Include references to the tags in the
        # serialization.
        format.xml  { render :xml => 
          bookmarks.to_xml(:except => except + [:id, :user_id],
                           :include => [:tags]) }
        # If the client requested Atom, turn the ActiveRecord objects
        # into an Atom feed.
        format.atom { render :xml => atom_feed_for(bookmarks, title, 
                                                   feed_uri, user) }
      end
    end
  end
##
  ## Helper methods

  # A wrapper for actions whose views support conditional HTTP GET.
  # If the given value for Last-Modified is after the incoming value
  # of If-Modified-Since, does nothing. If Last-Modified is before
  # If-Modified-Since, this method takes over the request and renders
  # a response code of 304 ("Not Modified").
  def render_not_modified_or(last_modified)
    response.headers['Last-Modified'] = last_modified.httpdate if last_modified

    if_modified_since = request.env['HTTP_IF_MODIFIED_SINCE']
    if if_modified_since && last_modified &&
        last_modified <= Time.httpdate(if_modified_since)
      # The representation has not changed since it was last requested.
      # Instead of processing the request normally, send a response
      # code of 304 ("Not Modified").
      render :nothing => true, :status => "304 Not Modified"
    else
      # The representation has changed since it was last requested.
      # Proceed with normal request processing.
      yield
    end
  end
##
  # A wrapper for actions which require the client to have named a
  # valid object. Sends a 404 response code if the client named a
  # nonexistent object. See the user_id_from_username filter for an
  # example.
  def if_found(obj)
    if obj
      yield 
    else
      render :text => "Not found.", :status => "404 Not Found"
      false
    end    
  end
##
  ## Filters

  # All actions should try to authenticate a user, even those actions
  # that don't require authorization. This is so we can show an
  # authenticated user their own private bookmarks.
  before_filter :authenticate

  # Sets @authenticated_user if the user provides valid
  # credentials. This may be used to deny access or to customize the
  # view.
  def authenticate    
    @authenticated_user = nil
    authenticate_with_http_basic do |user, pass|      
      @authenticated_user = User.authenticated_user(user, pass)
    end
    return true
  end

  # A filter for actions that _require_ authentication. Unless the
  # client has authenticated as some user, takes over the request and
  # sends a response code of 401 ("Unauthorized").  Also responds with
  # a 401 if the user is trying to operate on some user other than
  # themselves. This prevents users from doing things like deleting
  # each others' accounts.
  def must_authenticate    
    if @authenticated_user && (@user_is_viewing_themselves != false)
      return true
    else
      request_http_basic_authentication("Social bookmarking service")      
      return false
    end    
  end

  # A filter for controllers beneath /users/{username}. Transforms 
  # {username} into a user ID. Sends a 404 response code if the user
  # doesn't exist.
  def must_specify_user
    if params[:username]
      @user = User.find_by_name(params[:username])      
      if_found(@user) { params[:user_id] = @user.id }
      return false unless @user
    end
    @user_is_viewing_themselves = (@authenticated_user == @user)
    return true
  end
##

  ## Methods for generating a representation

  # This method converts an array of ActiveRecord's Bookmark objects
  # into an Atom feed.
  def atom_feed_for(bookmarks, title, feed_uri, user=nil)
    feed = Atom::Feed.new
    feed.title = title
    most_recent_bookmark = bookmarks.max do |b1,b2|
      b1.timestamp <=> b2.timestamp
    end
    feed.updated = most_recent_bookmark.timestamp

    # Link this feed to itself
    self_link = feed.links.new
    self_link['rel'] = 'self'
    self_link['href'] = feed_uri + ".atom"

    # If this list is a list of bookmarks from a single user, that user is
    # the author of the feed.
    if user
      user_to_atom_author(user, feed)
    end

    # Turn each bookmark in the list into an entry in the feed.
    bookmarks.each do |bookmark|
      entry = feed.entries.new
      entry.title = bookmark.short_description
      entry.content = bookmark.long_description

      # In a real application, a bookmark would have a separate
      # "modification date" field which was not under the control of
      # the user. This would also make the Last-Modified calculations
      # more accurate.
      entry.updated = bookmark.timestamp      

      # First, link this Atom entry to the external URI that the
      # bookmark tracks.
      external_uri = entry.links.new
      external_uri['href'] = bookmark.uri

      # Now we give some connectedness to this service. Link this Atom
      # entry to this service's resource for this bookmark.
      bookmark_resource = entry.links.new
      bookmark_resource['rel'] = "self"
      bookmark_resource['href'] = bookmark_url(bookmark.user.name, 
                                               bookmark.uri_hash) + ".atom"
      bookmark_resource['type'] = "application/xml+atom"

      # Then link this entry to the list of users who've bookmarked
      # this URI.
      other_users = entry.links.new
      other_users['rel'] = "related"
      other_users['href'] = uri_url(bookmark.uri_hash) + ".atom"
      other_users['type'] = "application/xml+atom"

      # Turn this entry's user into the "author" of this entry, unless
      # we already specified a user as the "author" of the entire
      # feed.
      unless user
        user_to_atom_author(bookmark.user, entry) 
      end

      # For each of this bookmark's tags...
      bookmark.tags.each do |tag|
        # ...represent the tag as an Atom category.
        category = entry.categories.new
        category['term'] = tag
        category['scheme'] = user_url(bookmark.user.name) + "/tags"

        # Link to this user's other bookmarks tagged using this tag.
        tag_uri = entry.links.new
        tag_uri['href'] = tag_url(bookmark.user.name, tag.name) + ".atom"
        tag_uri['rel'] = 'related'
        tag_uri['type'] = "application/xml+atom"

        # Also link to all bookmarks tagged with this tag.
        recent_tag_uri = entry.links.new
        recent_tag_uri['href'] = recent_url(tag.name) + ".atom"
        recent_tag_uri['rel'] = 'related'
        recent_tag_uri['type'] = "application/xml+atom"
      end
    end 
    return feed.to_xml
  end

  # Appends a representation of the given user to an Atom feed or element
  def user_to_atom_author(user, atom)
    author = atom.authors.new
    author.name = user.full_name
    author.email = user.email
    author.uri = user_url(user.name)
  end
end
