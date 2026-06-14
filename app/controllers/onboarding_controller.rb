class OnboardingController < ApplicationController
  def show
    redirect_to game_path if Current.user.onboarding_complete?
  end
end
