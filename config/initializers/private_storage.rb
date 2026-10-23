# Published images are served by nginx; Rails previews require the existing login.
if ENV["STATIC_PUBLISH_TARGET"].present?
  Rails.application.config.to_prepare do
    ActiveStorage::BaseController.include Authentication
  end
end
