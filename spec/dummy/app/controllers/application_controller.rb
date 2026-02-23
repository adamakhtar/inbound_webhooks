class ApplicationController < ActionController::Base
  private

  def authorize_user!
    unless current_user&.admin?
      head :forbidden
    end
  end
end
