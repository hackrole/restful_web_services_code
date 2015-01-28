class TagsController < ApplicationController
  before_filter :must_specify_user
  before_filter :must_authenticate, :only => [:update]

  # GET /users/{username}/tags
  def index    
    # A user can see all of their own tags, but only tags used
    # in someone else's public bookmarks.
    if @user_is_viewing_themselves
      tag_restriction = ''
    else
      tag_restriction = " AND bookmarks.public='1'"
    end
    sql = ["SELECT tags.*, COUNT(bookmarks.id) as count" +
           " FROM tags, bookmarks, taggings" +
           " WHERE taggings.taggable_type = 'Bookmark'" +
           " AND tags.id = taggings.tag_id" +
           " AND taggings.taggable_id = bookmarks.id" + 
           " AND bookmarks.user_id = ?" + tag_restriction +
           " GROUP BY tags.name", @user.id]
    # Find a bunch of ActiveRecord Tag objects using custom SQL.
    tags = Tag.find_by_sql(sql)

    # Convert the Tag objects to an XML document.
    render :xml => tags.to_xml(:except => [:id])
  end
##
  # PUT /users/{username}/tags/{tag} 
  # This PUT handler is a little tricker than others, because we
  # can't just rename a tag site-wide. Other users might be using the
  # same tag.  We need to find every bookmark where this user uses the
  # tag, strip the "old" name, and add the "new" name on.
  def update
    old_name = params[:id]
    new_name = params[:tag][:name] if params[:tag]
    if new_name
      # Find all this user's bookmarks tagged with the old name
      to_change = Bookmark.find(["bookmarks.user_id = ?", @user.id], 
                                old_name)
      # For each such bookmark...
      to_change.each do |bookmark|
        # Find its tags.
        tags = bookmark.tags.collect { |tag| tag.name }
        # Remove the old name.
        tags.delete(old_name)
        # Add the new name.
        tags << new_name
        # Assign the new set of tags to the bookmark.
        bookmark.tag_with tags.uniq
      end
      headers['Location'] = tag_url(@user.name, new_name)
      status = "301 Moved Permanently"
    end
    render :nothing => true, :status => status || "200 OK"
  end

  # GET /users/{username}/tags/{tag}
  def show
    # Show bookmarks that belong to this user and are tagged
    # with the given tag.
    tag = params[:id]
    show_bookmarks(["bookmarks.user_id = ?", @user.id], 
                   "#{@user.name}'s bookmarks tagged with '#{tag}'",
                   tag_url(@user.name, tag), @user, tag)
  end
end
