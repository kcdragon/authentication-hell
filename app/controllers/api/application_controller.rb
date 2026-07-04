class Api::ApplicationController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
end
