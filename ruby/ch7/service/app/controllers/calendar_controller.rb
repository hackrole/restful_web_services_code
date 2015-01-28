class CalendarController < ApplicationController
  before_filter :must_specify_user

  # GET /users/{username}/calendar
  def index
    calendar = Bookmark.calendar(@user.id, @user_is_viewing_themselves)
    render :xml => calendar_to_xml(calendar)
  end

  # GET /users/{username}/calendar/{tag}
  def show    
    tag = params[:id]
    calendar = Bookmark.calendar(@user.id, @user_is_viewing_themselves,
                                 tag)
    render :xml => calendar_to_xml(calendar, tag)
  end

  private

  # Build an XML document out of the data structure returned by the
  # Bookmark.calendar method.
  def calendar_to_xml(days, tag=nil)
    xml = Builder::XmlMarkup.new(:indent => 2)
    xml.instruct!
    # Build a 'calendar' element.
    xml.calendar(:tag => tag) do
      # For every day in the data structure...
      days.each do |day|
        # ...add a "day" element to the document
        xml.day(:date => day.date, :count => day.count)
      end
    end
  end
end
