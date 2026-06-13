class UsersController < ApplicationController
  def show
  end

  def update
    if Current.user.update(user_params)
      redirect_to user_path, notice: "Avatar updated."
    else
      flash.now[:alert] = Current.user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:avatar)
  end
end
