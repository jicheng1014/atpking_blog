module Admin
  class SettingsController < Admin::ApplicationController
    def edit
      @site_name = Setting.site_name
      @post_signature = Setting.post_signature
      @icp_number = Setting.icp_number
    end

    def update
      Setting.set('site_name', params[:site_name])
      Setting.set('post_signature', params[:post_signature])
      Setting.set('icp_number', params[:icp_number])

      redirect_to admin_settings_path, notice: '设置已更新'
    end
  end
end
