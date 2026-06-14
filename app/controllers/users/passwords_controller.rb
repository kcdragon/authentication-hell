class Users::PasswordsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to password_change_path, alert: "Try again later." }

  def show
  end

  def update
    user = Current.user

    # A passwordless (passkey-only) user has nothing to verify; everyone else must prove the current one.
    unless user.passwordless? || user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      return render :show, status: :unprocessable_entity
    end

    # has_secure_password silently ignores a blank password, and the model has no presence rule.
    if password_params[:password].blank?
      user.errors.add(:password, "can't be blank")
    elsif user.update(password_params)
      user.sessions.where.not(id: Current.session.id).destroy_all
      return redirect_to password_change_path, notice: "Password updated."
    end

    flash.now[:alert] = user.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  private

  def password_params
    params.expect(user: [ :password, :password_confirmation ])
  end
end
