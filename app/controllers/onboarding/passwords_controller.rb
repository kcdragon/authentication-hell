class Onboarding::PasswordsController < ApplicationController
  def create
    user = Current.user

    # has_secure_password silently ignores a blank password, and the model has no presence rule.
    if password_params[:password].blank?
      user.errors.add(:password, "can't be blank")
    elsif user.update(password_params)
      return redirect_to onboarding_path, notice: "Password set."
    end

    flash.now[:alert] = user.errors.full_messages.to_sentence
    render "onboarding/show", status: :unprocessable_entity
  end

  private

  def password_params
    params.expect(user: [ :password, :password_confirmation ])
  end
end
