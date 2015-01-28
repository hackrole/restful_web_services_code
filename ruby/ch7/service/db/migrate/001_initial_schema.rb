class InitialSchema < ActiveRecord::Migration

  # Create the database tables on a Rails migration.
  def self.up
    # The 'users' table, tracking four items of state 
    # plus a unique ID.
    create_table :users, :force => true do |t|
      t.column :name, :string
      t.column :full_name, :string
      t.column :email, :string
      t.column :password, :string
    end

    # The 'bookmarks' table, tracking six items of state,
    # plus a derivative field and a unique ID.
    create_table :bookmarks, :force => true do |t|
      t.column :user_id, :string
      t.column :uri, :string
      t.column :uri_hash, :string   # A hash of the URI.
                                    # See book text below.
      t.column :short_description, :string
      t.column :long_description, :text
      t.column :timestamp, :datetime
      t.column :public, :boolean
    end

    # This join table reflects the fact that bookmarks are subordinate
    # resources to users.
    create_table :user_bookmarks, :force => true do |t|
      t.column :user_id, :integer
      t.column :bookmark_id, :integer
    end

    # These two are standard tables defined by the acts_as_taggable
    # plugin, of which more later. This one defines tags.
    create_table :tags do |t|
      t.column :name, :string
    end

    # This one defines the relationship between tags and the things
    # tagged--in this case, bookmarks.
    create_table :taggings do |t|
      t.column :tag_id, :integer
      t.column :taggable_id, :integer
      t.column :taggable_type, :string
    end

    # Four indexes that capture the ways I plan to search the
    # database.
    add_index :users, :name
    add_index :bookmarks, :uri_hash
    add_index :tags, :name
    add_index :taggings, [:tag_id, :taggable_id, :taggable_type]
  end

  # Drop the database tables on a Rails reverse migration.
  def self.down
    [:users, :bookmarks, :tags, :user_bookmarks, :taggings].each do |t|
      drop_table t
    end
  end
end
