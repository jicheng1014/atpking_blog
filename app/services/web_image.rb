require "vips"
require "base64"
require "digest"

# A normalized WebP is the stored asset, not an extra permanent variant.
class WebImage
  VERSION = 1
  MAX_EDGE = 1920

  def self.convert(path, content_type:)
    return nil if content_type == "image/svg+xml" || !content_type.start_with?("image/")
    options = { height: MAX_EDGE, size: :down }
    source = path.to_s
    source += "[n=-1]" if %w[image/gif image/webp].include?(content_type)
    image = Vips::Image.thumbnail(source, MAX_EDGE, **options).copy_memory
    height = image.get_typeof("page-height").positive? ? image.get("page-height") : image.height
    bytes = image.webpsave_buffer(Q: 82, effort: 4, strip: true)
    # Decode the result before any old asset is removed.
    check = Vips::Image.new_from_buffer(bytes, "", n: -1)
    raise "Image dimensions changed unexpectedly" unless check.width == image.width && check.height == image.height
    preview = image.crop(0, 0, image.width, height).thumbnail_image(24, height: 24, size: :down)
    metadata = { "web_image_version" => VERSION, "width" => image.width, "height" => height,
      "lqip" => "data:image/webp;base64,#{Base64.strict_encode64(preview.webpsave_buffer(Q: 25, strip: true))}",
      "identified" => true, "analyzed" => true }
    [bytes, metadata]
  end

  def self.normalize!(blob)
    return if blob.metadata["web_image_version"] == VERSION
    old_key = nil
    blob.with_lock do
      return if blob.metadata["web_image_version"] == VERSION
      blob.open do |file|
        result = convert(file.path, content_type: blob.content_type.to_s)
        return unless result
        bytes, metadata = result
        old_key = blob.key
        key = ActiveStorage::Blob.generate_unique_secure_token
        checksum = Digest::MD5.base64digest(bytes)
        blob.service.upload(key, StringIO.new(bytes), checksum: checksum, content_type: "image/webp")
        begin
          blob.update!(key: key, filename: "#{blob.filename.base}.webp", content_type: "image/webp",
            byte_size: bytes.bytesize, checksum: checksum, metadata: blob.metadata.merge(metadata))
        rescue
          blob.service.delete(key)
          raise
        end
        # This file is now replaceable; the pre-migration archive retains recovery evidence.
      end
    end
    blob.service.delete(old_key) if old_key
  end
end
