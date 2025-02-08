class ResizeImageJob < ApplicationJob
  queue_as :default

  def perform(blob)
    return unless blob.image?
    return if blob.metadata['processed']

    blob.open do |tempfile|
      # 使用 image_processing gem 处理图片
      processed = ImageProcessing::MiniMagick
        .source(tempfile)
        .resize_to_limit(1024, 1024)
        .call

      # 更新 blob 的内容
      blob.update!(
        io: File.open(processed.path),
        filename: blob.filename,
        content_type: blob.content_type,
        metadata: blob.metadata.merge('processed' => true)
      )
    end
  end
end
