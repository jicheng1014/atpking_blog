class ProcessPostImagesJob < ApplicationJob
  queue_as :default

  # Keep the class for already queued jobs, but never overwrite original image bytes.
  def perform(*)
  end
end
