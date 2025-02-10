module Admin
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
    layout 'admin'

    private

    def authenticate_user!
      unless current_user
        store_location
        redirect_to new_session_path, alert: "请先登录"
      end
    end

    def store_location
      session[:return_to] = request.fullpath if request.get?
    end
  end
end
