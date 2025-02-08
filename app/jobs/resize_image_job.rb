class ResizeImageJob < ApplicationJob
  queue_as :default

  def perform(blob)
    return unless blob.image?
    return if blob.metadata['processed']

    blob.open do |original|
      # 使用 image_processing gem 处理图片
      processed = ImageProcessing::MiniMagick
        .source(original)
        .resize_to_limit(1024, 1024)
        .call

      # 使用新的处理后的文件创建一个新的 blob
      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(processed.path),
        filename: blob.filename,
        content_type: blob.content_type,
        metadata: blob.metadata.merge('processed' => true)
      )

      # 更新所有引用原始 blob 的附件，指向新的 blob
      blob.attachments.each do |attachment|
        attachment.update!(blob: new_blob)
      end

      # 删除原始 blob
      blob.purge
    end
  end
end
