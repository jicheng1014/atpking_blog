class CleanupOrphanedImagesJob < ApplicationJob
  queue_as :default

  def perform
    # 查找所有被标记为孤立的图片
    orphaned_blobs = ActiveStorage::Blob.where("metadata->>'orphaned' = 'true'")

    # 记录开始清理的日志
    Rails.logger.info "Starting cleanup of #{orphaned_blobs.count} orphaned images"

    # 逐个清理孤立的图片
    orphaned_blobs.find_each do |blob|
      begin
        # 再次检查这个 blob 是否真的没有被引用
        unless Post.where("content LIKE ?", "%#{blob.signed_id}%").exists?
          # 如果确实没有被引用，就删除它
          blob.purge
          Rails.logger.info "Successfully purged orphaned image: #{blob.filename}"
        else
          # 如果发现有引用，就移除孤立标记
          blob.update_column(:metadata, blob.metadata.merge('orphaned' => false))
          Rails.logger.info "Found references for previously orphaned image: #{blob.filename}"
        end
      rescue => e
        Rails.logger.error "Failed to process orphaned image #{blob.filename}: #{e.message}"
      end
    end

    # 记录完成清理的日志
    Rails.logger.info "Completed orphaned images cleanup"
  end
end
