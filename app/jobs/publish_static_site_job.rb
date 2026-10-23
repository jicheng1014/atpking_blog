class PublishStaticSiteJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: ->(executions) { 2**executions }, attempts: 3

  def self.enqueue_if_configured
    perform_later if ENV["STATIC_PUBLISH_TARGET"].present?
  end

  def self.publication_status
    JSON.parse(Rails.root.join("storage/static-publish-status.json").read)
  rescue Errno::ENOENT, JSON::ParserError
    {}
  end

  def record_status(state, error = nil)
    status = self.class.publication_status.merge("state" => state, "at" => Time.current.iso8601, "error" => error)
    status["last_success_at"] = status["at"] if state == "succeeded"
    path = Rails.root.join("storage/static-publish-status.json")
    temporary = Pathname("#{path}.#{Process.pid}.tmp")
    temporary.write(JSON.generate(status))
    File.rename(temporary, path)
  end

  def perform
    return unless ENV["STATIC_PUBLISH_TARGET"].present?

    FileUtils.mkdir_p(Rails.root.join("tmp/static-releases"))
    File.open(Rails.root.join("tmp/static-publish.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      release = Rails.root.join("tmp/static-releases", "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}")
      begin
        record_status("publishing")
        StaticSiteExporter.new(release).call
        success = system(Rails.root.join("script/publish-static-site").to_s, release.to_s)
        raise "Static site transport failed" unless success
        record_status("succeeded")
      rescue StandardError => error
        record_status("failed", error.message.truncate(300))
        raise
      ensure
        FileUtils.rm_rf(release)
      end
    end
  rescue StandardError => error
    Rails.logger.error("Static site publish failed: #{error.class}: #{error.message}")
    raise
  end
end
