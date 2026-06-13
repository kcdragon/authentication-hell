class AvatarsController < ApplicationController
  def destroy
    Current.user.avatar.purge_later
    redirect_to user_path, notice: "Avatar removed."
  end
end
