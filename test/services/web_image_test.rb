require "test_helper"

class WebImageTest < ActiveSupport::TestCase
  test "normalizes large photos with orientation, bounded dimensions and compatible signed ID" do
    image = Vips::Image.black(3000, 2000).new_from_image([50, 130, 200])
    image.set_type(GObject::GINT_TYPE, "orientation", 6)
    bytes = image.jpegsave_buffer(Q: 98)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "photo.jpg", content_type: "image/jpeg")
    signed = blob.signed_id
    old_key = blob.key
    WebImage.normalize!(blob)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed)
    assert_equal "image/webp", blob.content_type
    assert_equal [1280, 1920], blob.metadata.values_at("width", "height")
    assert blob.byte_size < bytes.bytesize
    refute blob.service.exist?(old_key)
    assert blob.metadata["lqip"].start_with?("data:image/webp;base64,")
    assert_equal "WEBP", blob.download[8, 4]
    key = blob.key
    WebImage.normalize!(blob)
    assert_equal key, blob.key
  ensure
    blob&.purge
  end

  test "keeps transparency and animation frame timing" do
    frame = Vips::Image.black(32, 32)
    image = frame.new_from_image([255, 0, 0, 90]).join(frame.new_from_image([0, 255, 0, 150]), :vertical)
    image.set_type(GObject::GINT_TYPE, "page-height", 32)
    image.set_type(Vips::ARRAY_INT_TYPE, "delay", [100, 200])
    bytes = image.webpsave_buffer
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "animated.webp", content_type: "image/webp")
    WebImage.normalize!(blob)
    decoded = Vips::Image.new_from_buffer(blob.download, "", n: -1)
    assert_equal 64, decoded.height
    assert_equal 32, decoded.get("page-height")
    assert_equal [100, 200], decoded.get("delay")
    assert decoded.has_alpha?
  ensure
    blob&.purge
  end
end
