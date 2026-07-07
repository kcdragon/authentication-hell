class Editor::ApplicationController < ApplicationController
  # WASM can't send a CSRF token.
  skip_forgery_protection

  before_action :ensure_development

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render json: { ok: false, errors: [ "invalid JSON" ] }, status: :bad_request
  end

  private

  def ensure_development
    head :not_found unless Rails.env.development?
  end
end
