class Bookmark < ActiveRecord::Base
  # Every bookmark belongs to some user.
  belongs_to :user

  # A bookmark can have tags. The relationships between bookmarks and
  # tags are managed by the acts_as_taggable plugin.
  acts_as_taggable

  # A bookmark must have an associated user ID, a URI, a short
  # description, and a timestamp.
  validates_presence_of :user_id, :uri, :short_description, :timestamp

  # The URI hash should never be changed directly: only when the URI
  # changes.
  attr_protected :uri_hash

  # And.. here's the code to update the URI hash when the URI changes.
  def uri=(new_uri)
    super
    self.uri_hash = Digest::MD5.new(new_uri).to_s
  end

  # This method is triggered by Bookmark.new and by
  # Bookmark#update_attributes. It replaces a bookmark's current set
  # of tags with a new set.
  def tag_with(tags)
    Tag.transaction do
      taggings.destroy_all
      tags.each { |name| Tag.find_or_create_by_name(name).on(self) }
    end
  end
##
  # This method finds bookmarks, possibly ones tagged with a
  # particular tag.
  def self.custom_find(conditions, tag=nil, limit=nil)
    if tag       
      # When a tag restriction is specified, we have to find bookmarks
      # the hard way: by constructing a SQL query that matches only
      # bookmarks tagged with the right tag.
      sql = ["SELECT bookmarks.* FROM bookmarks, tags, taggings" +
             " WHERE taggings.taggable_type = 'Bookmark'" +
             " AND bookmarks.id = taggings.taggable_id" +
             " AND taggings.tag_id = tags.id AND tags.name = ?",
             tag]
      if conditions
        sql[0] << " AND " << conditions[0]
        sql += conditions[1..conditions.size]
      end
      sql[0] << " ORDER BY bookmarks.timestamp DESC"
      sql[0] << " LIMIT " << limit.to_i.to_s if limit
      bookmarks = find_by_sql(sql)
    else
      # Without a tag restriction, we can find bookmarks the easy way:
      # with the superclass find() implementation.
      bookmarks = find(:all, {:conditions => conditions, :limit => limit,
                              :order => 'timestamp DESC'})
    end    
    return bookmarks
  end
##
  # Restricts a bookmark query so that it only finds bookmarks visible
  # to the given user. This means public bookmarks, and the given
  # user's private bookmarks.
  def self.only_visible_to!(conditions, user)
    # The first element in the "conditions" array is a SQL WHERE
    # clause with variable substitutions. The subsequent elements are
    # the variables whose values will be substituted. For instance,
    # if "conditions" starts out empty: [""]...

    conditions[0] << " AND " unless conditions[0].empty?
    conditions[0] << "(public='1'"
    if user
      conditions[0] << " OR user_id=?"
      conditions << user.id
    end
    conditions[0] << ")"

    # ...its value might now be ["(public='1' or user_id=?)", 55].
    # ActiveRecord knows how to turn this into the SQL WHERE clause
    # "(public='1' or user_id=55)".
  end 

  # This method retrieves data for the CalendarController. It uses the
  # SQL DATE() function to group together entries made on a particular
  # day.
  def self.calendar(user_id, viewed_by_owner, tag=nil)    
    if tag
      tag_from = ", tags, taggings"
      tag_where = "AND taggings.taggable_type = 'Bookmark'" +
        " AND bookmarks.id = taggings.taggable_id" +
        " AND taggings.tag_id = tags.id AND tags.name = ?"
    end

    # Unless a user is viewing their own calendar, only count public
    # bookmarks.
    public_where = viewed_by_owner ? "" : "AND public='1'"

    sql = ["SELECT date(timestamp) AS date, count(bookmarks.id) AS count" +
           " FROM bookmarks#{tag_from} " +
           " WHERE user_id=? #{tag_where} #{public_where} " +
           " GROUP BY date(timestamp)", user_id]
    sql << tag if tag

    # This will return a list of rather bizarre ActiveRecord objects,
    # which CalendarController knows how to turn into an XML document.
    find_by_sql(sql)
  end
end
