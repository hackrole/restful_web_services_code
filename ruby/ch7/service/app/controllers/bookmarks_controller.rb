class BookmarksController < ApplicationController
  before_filter :must_specify_user
  before_filter :fix_params
  before_filter :must_authenticate, :only => [:create, :update, :destroy]

  # This filter cleans up incoming representations.
  def fix_params    
    if params[:bookmark]
      params[:bookmark][:user_id] = @user.id if @user
    end 
  end
##
  # GET /users/{username}/bookmarks
  def index
    # Show this user's bookmarks by passing in an appropriate SQL
    # restriction to show_bookmarks.
    show_bookmarks(["user_id = ?", @user.id],
                   "Bookmarks for #{@user.name}", 
                   bookmark_url(@user.name), @user)
  end

  # POST /users/{username}/bookmarks
  def create
    bookmark = Bookmark.find_by_user_id_and_uri(params[:bookmark][:user_id], 
                                                params[:bookmark][:uri])
    if bookmark
      # This user has already bookmarked this URI. They should be
      # using PUT instead.
      headers['Location'] = bookmark_url(@user.name, bookmark.uri)
      render :nothing => true, :status => "409 Conflict"
    else
      # Enforce default values for 'timestamp' and 'public'
      params[:bookmark][:timestamp] ||= Time.now
      params[:bookmark][:public] ||= "1"

      # Create the bookmark in the database.
      bookmark = Bookmark.new(params[:bookmark])
      if bookmark.save
        # Add tags.
        bookmark.tag_with(params[:taglist]) if params[:taglist]

        # Send a 201 response code that points to the location of the
        # new bookmark.
        headers['Location'] = bookmark_url(@user.name, bookmark.uri)
        render :nothing => true, :status => "201 Created"
      else
        render :xml => bookmark.errors.to_xml, :status => "400 Bad Request"
      end
    end
  end

  # PUT /users/{username}/bookmarks/{URI-MD5}
  def update
    bookmark = Bookmark.find_by_user_id_and_uri_hash(@user.id, params[:id])
    if_found bookmark do
      old_uri = bookmark.uri
      if old_uri != params[:bookmark][:uri] && 
          Bookmark.find_by_user_id_and_uri(@user.id, params[:bookmark][:uri])
        # The user is trying to change the URI of this bookmark to a
        # URI that they've already bookmarked. Conflict!
        render :nothing => true, :status => "409 Conflict"
      else
        # Update the bookmark's row in the database.
        if bookmark.update_attributes(params[:bookmark])
          # Change the bookmark's tags.
          bookmark.tag_with(params[:taglist]) if params[:taglist]
          if bookmark.uri != old_uri
            # The bookmark changed URIs. Send the new URI.
            headers['Location'] = bookmark_url(@user.name, bookmark.uri)
            render :nothing => true, :status => "301 Moved Permanently"
          else
            # The bookmark stayed where it was.
            render :nothing => true, :status => "200 OK"
          end
        else
          render :xml => bookmark.errors.to_xml, :status => "400 Bad Request"
        end
      end
    end
  end

  # GET /users/{username}/bookmarks/{uri}
  def show
    # Look up the requested bookmark, and render it as a "list"
    # containing only one item.
    bookmark = Bookmark.find_by_user_id_and_uri_hash(@user.id, params[:id])
    if_found(bookmark) do
      render_bookmarks([bookmark], 
                       "#{@user.name} bookmarked #{bookmark.uri}",
                       bookmark_url(@user.name, bookmark.uri_hash),
                       @user)
    end
  end

  # DELETE /users/{username}/bookmarks/{uri}
  def destroy
    bookmark = Bookmark.find_by_user_id_and_uri_hash(@user.id, params[:id])
    if_found bookmark do
      bookmark.destroy
      render :nothing => true, :status => "200 OK"
    end
  end
end
