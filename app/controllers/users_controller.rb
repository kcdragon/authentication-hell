class UsersController < ApplicationController
  helper_method :earned_achievements_by_key

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

  def earned_achievements_by_key
    @earned_achievements_by_key ||= Current.user.earned_achievements.index_by(&:achievement_key)
  end

  def user_params
    params.require(:user).permit(:avatar)
  end
end
