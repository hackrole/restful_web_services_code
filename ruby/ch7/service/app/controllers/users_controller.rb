class UsersController < ApplicationController  

  # A client must authenticate to modify or delete a user account.
  before_filter :must_authenticate, :only => [:modify, :destroy]

  # POST /users
  def create   
    user = User.find_by_name(params[:user][:name])
    if user
      # The client tried to create a user that already exists.
      headers['Location'] = user_url(user.name)
      render :nothing => true, :status => "409 Conflict"
    else   
      user = User.new(params[:user])
      if user.save
        headers['Location'] = user_path(user.name)
        render :nothing => true, :status => "201 Created"
      else
        # There was a problem saving the user to the database.
        # Send the validation error messages along with a response
        # code of 400.
        render :xml => user.errors.to_xml, :status => "400 Bad Request"
      end
    end
  end
##
  # PUT /users/{username}
  def update
    old_name = params[:id]
    new_name = params[:user][:name]
    user = User.find_by_name(old_name)

    if_found user do
      if old_name != new_name && User.find_by_name(new_name)
        # The client tried to change this user's name to a name
        # that's already taken. Conflict!
        render :nothing => true, :status => "409 Conflict"      
      else        
        # Save the user to the database.
        user.update_attributes(params[:user])        
        if user.save
          # The user's name changed, which changed its URI.
          # Send the new URI.
          if user.name != old_name
            headers['Location'] = user_path(user.name)
            status = "301 Moved Permanently"
          else
            # The user resource stayed where it was.
            status = "200 OK"
          end
          render :nothing => true, :status => status
        else
          # There was a problem saving the bookmark to the database.
          # Send the validation error messages along with a response
          # code of 400.
          render :xml => user.errors.to_xml, :status => "400 Bad Request"
        end
      end
    end
  end
##
  # GET /users/{username}
  def show
    # Find the user in the database.
    user = User.find_by_name(params[:id])
    if_found(user) do
      # Serialize the User object to XML with ActiveRecord's to_xml.
      # Don't include the user's ID or password when building the XML
      # document.
      render :xml => user.to_xml(:except => [:id, :password])
    end
  end

  # DELETE /users/{username}
  def destroy
    user = User.find_by_name(params[:id])
    if_found user do
      # Remove the user from the database.
      user.destroy
      render :nothing => true, :status => "200 OK"
    end
  end
end
