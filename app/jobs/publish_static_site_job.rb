class PublishStaticSiteJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: ->(executions) { 2**executions }, attempts: 3

  def self.enqueue_if_configured
    perform_later if ENV["STATIC_PUBLISH_TARGET"].present?
  end

  def perform
    return unless ENV["STATIC_PUBLISH_TARGET"].present?

    FileUtils.mkdir_p(Rails.root.join("tmp/static-releases"))
    File.open(Rails.root.join("tmp/static-publish.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      release = Rails.root.join("tmp/static-releases", "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}")
      begin
        StaticSiteExporter.new(release).call
        success = system(Rails.root.join("script/publish-static-site").to_s, release.to_s)
        raise "Static site transport failed" unless success
      ensure
        FileUtils.rm_rf(release)
      end
    end
  rescue StandardError => error
    Rails.logger.error("Static site publish failed: #{error.class}: #{error.message}")
    raise
  end
end
