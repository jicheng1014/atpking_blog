class ResizeImageJob < ApplicationJob
  # 这个 Job 已经不再需要了，我们将使用 ActiveStorage 的 variant 功能
  # 保留这个文件是为了确保没有遗留的任务在队列中
  queue_as :default

  def perform(blob)
    return unless blob.image?
    return if blob.metadata['processed']

    begin
      # 生成 variant 并确保它被处理
      variant = blob.variant(resize_to_limit: [1024, 1024]).processed

      # 只有当 variant 成功创建时才更新 metadata
      if variant.present?
        blob.update!(metadata: blob.metadata.merge(
          'processed' => true,
          'variant_key' => variant.variation.key
        ))
      end
    rescue => e
      Rails.logger.error "Failed to process image variant: #{e.message}"
      raise e # 重新抛出异常以便任务重试
    end
  end
end
