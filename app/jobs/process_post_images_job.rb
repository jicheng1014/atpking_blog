class ProcessPostImagesJob < ApplicationJob
  queue_as :default

  def perform(post_id = nil)
    if post_id
      process_post_images(Post.find(post_id))
    else
      Post.find_each do |post|
        process_post_images(post)
      end
    end
  end

  private

  def process_post_images(post)
    extract_image_urls(post.content).each do |url|
      process_single_image(url, post.id) if valid_blob_url?(url)
    end
  end

  def extract_image_urls(content)
    content.scan(/!\[.*?\]\((\/rails\/active_storage\/blobs\/.*?)\)/).flatten
  end

  def valid_blob_url?(url)
    url =~ /\/rails\/active_storage\/blobs\/(.*?)\//
  end

  def find_blob_from_url(url)
    if url =~ /\/rails\/active_storage\/blobs\/(.*?)\//
      ActiveStorage::Blob.find_signed($1)
    end
  end

  def process_single_image(url, post_id)
    blob = find_blob_from_url(url)
    return unless should_process_image?(blob)

    Rails.logger.info "Processing image #{blob.filename} for post #{post_id}"

    process_with_tempfile(blob) do |original_file|
      if needs_resizing?(blob)
        resize_image(blob, original_file)
      else
        mark_as_skipped(blob)
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "Cannot find blob for URL: #{url} in post #{post_id}"
  rescue => e
    Rails.logger.error "Error processing image for post #{post_id}: #{e.message}"
  end

  def should_process_image?(blob)
    blob&.image? && !blob.metadata['processed']
  end

  def process_with_tempfile(blob)
    # 创建临时目录
    temp_dir = Rails.root.join('tmp', 'image_processing', SecureRandom.hex)
    FileUtils.mkdir_p(temp_dir)

    begin
      # 下载原始文件到临时文件
      original_temp = temp_dir.join("original_#{blob.filename}")
      processed_temp = temp_dir.join("processed_#{blob.filename}")

      blob.download do |chunk|
        original_temp.open('ab') { |f| f.write(chunk) }
      end

      yield(original_temp)

      # 如果文件被修改了，上传回存储服务
      if File.exist?(processed_temp)
        blob.service.upload(blob.key, processed_temp)
      end
    ensure
      # 清理临时文件
      FileUtils.rm_rf(temp_dir)
    end
  end

  def needs_resizing?(blob)
    metadata = analyze_image(blob)
    metadata[:width] > 1024 || metadata[:height] > 1024
  end

  def analyze_image(blob)
    analyzer = ActiveStorage::Analyzer::ImageAnalyzer.new(blob)
    analyzer.metadata
  end

  def resize_image(blob, original_path)
    metadata = analyze_image(blob)
    processed_path = Pathname.new(original_path.to_s.sub('original_', 'processed_'))

    processor = ActiveStorage::Transformers::ImageProcessingTransformer.new(
      :resize_to_limit => [1024, 1024]
    )

    # 处理图片
    File.open(original_path, 'rb') do |input|
      File.open(processed_path, 'wb') do |output|
        processor.process(input, output)
      end
    end

    # 更新元数据
    update_metadata(blob, {
      'processed' => true,
      'processed_at' => Time.current.iso8601,
      'original_size' => metadata,
      'processed_size' => analyze_processed_image(processed_path)
    })

    Rails.logger.info "Successfully processed image #{blob.filename}"
  end

  def analyze_processed_image(path)
    image = MiniMagick::Image.new(path)
    {
      width: image.width,
      height: image.height,
      size: File.size(path)
    }
  end

  def mark_as_skipped(blob)
    metadata = analyze_image(blob)
    update_metadata(blob, {
      'processed' => true,
      'processed_at' => Time.current.iso8601,
      'skipped' => true,
      'reason' => 'image size within limits',
      'size' => metadata
    })
    Rails.logger.info "Skipped processing for #{blob.filename} as it's already within size limits"
  end

  def update_metadata(blob, new_metadata)
    blob.update_column(:metadata, blob.metadata.merge(new_metadata))
  end
end
