class AddCleanupOrphanedImagesJob < ActiveRecord::Migration[8.0]
  def up
    # 获取所有文章中引用的图片 URL
    used_blobs = Set.new
    Post.find_each do |post|
      urls = post.content.scan(/!\[.*?\]\((\/rails\/active_storage\/blobs\/.*?)\)/).flatten
      urls.each do |url|
        if url =~ /\/rails\/active_storage\/blobs\/(.*?)\//
          used_blobs.add($1)
        end
      end
    end

    # 获取所有的 blobs
    ActiveStorage::Blob.find_each do |blob|
      next unless blob.content_type.start_with?('image/')

      # 如果这个 blob 没有被任何文章引用，标记为待清理
      unless used_blobs.include?(blob.signed_id)
        blob.update_column(:metadata, blob.metadata.merge('orphaned' => true))
      end
    end

    # 创建一个清理任务
    say_with_time "Creating cleanup job for orphaned images" do
      blob_count = ActiveStorage::Blob.where("metadata->>'orphaned' = 'true'").count
      say "Found #{blob_count} orphaned images"
    end
  end

  def down
    ActiveStorage::Blob.where("metadata->>'orphaned' = 'true'").update_all(
      "metadata = metadata - 'orphaned'"
    )
  end
end
