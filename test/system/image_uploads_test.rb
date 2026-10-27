require "application_system_test_case"

class ImageUploadsTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit new_session_path
    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_button "登录"
    assert_selector "a", text: "管理", wait: 10
    visit root_path
    assert_selector "[data-controller='paste-image quick-post']"
    @image = Tempfile.new(["upload-preview", ".png"])
    @image.binmode
    @image.write(Vips::Image.black(80, 60).new_from_image([40, 100, 160]).pngsave_buffer)
    @image.flush
  end

  teardown do
    @image&.close!
  end

  test "waits for server processing, preserves edits, previews and publishes a real uploaded image" do
    release = Queue.new
    convert = WebImage.method(:convert)
    WebImage.define_singleton_method(:convert) { |*args, **options| release.pop; convert.call(*args, **options) }
    begin
      fill_in "thought_content", with: "上传时继续记录"
      find("[data-paste-image-target='fileInput']", visible: :all).attach_file @image.path, make_visible: true
      assert_selector ".image-upload[data-state='processing']", text: "正在处理图片"
      assert_button "上传中…", disabled: true
      fill_in "thought_content", with: "上传期间新增的文字不能丢失"
      find("#thought_content").send_keys([:control, :enter])
      page.execute_script("document.querySelector('[data-controller=\"paste-image quick-post\"]').requestSubmit()")
      assert_current_path root_path
      assert_selector ".image-upload[data-state='processing']"
      release << true
      assert_selector ".image-upload[data-state='uploaded']", text: "已上传"
    ensure
      WebImage.define_singleton_method(:convert, convert)
      release << true
    end
    assert_field "thought_content", with: "上传期间新增的文字不能丢失"
    assert_button "发布", disabled: false
    find(".image-upload-preview").click
    assert_selector "dialog[open] img"
    find("[aria-label='关闭图片预览']").click
    assert_no_selector "dialog[open]"

    page.save_screenshot(Rails.root.join("tmp/thought-upload-desktop.png"))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    page.save_screenshot(Rails.root.join("tmp/thought-upload-mobile.png"))
    click_button "发布"
    assert_text "灵感已发布"
    thought = Thought.order(:id).last
    assert_includes thought.content, "上传期间新增的文字不能丢失"
    assert_equal 1, thought.images.count
    assert_selector ".home-thought-content img"
  end

  test "failed images block submission until retried or removed without losing text" do
    invalid = Tempfile.new(["invalid-image", ".png"])
    invalid.write("not a valid image")
    invalid.flush
    fill_in "thought_content", with: "失败也要保留的随想"
    find("[data-paste-image-target='fileInput']", visible: :all).attach_file invalid.path, make_visible: true
    assert_selector ".image-upload[data-state='failed']", text: "图片上传失败"
    assert_button "待处理", disabled: true
    find("#thought_content").send_keys([:control, :enter])
    assert_current_path root_path
    click_button "重试"
    assert_selector ".image-upload[data-state='failed']"
    assert_field "thought_content", with: "失败也要保留的随想"
    find(".image-upload-remove").click
    assert_no_selector ".image-upload"
    assert_button "发布", disabled: false
    click_button "发布"
    assert_text "灵感已发布"
    assert_text "失败也要保留的随想"
  ensure
    invalid&.close!
  end

  test "article editor retains Markdown upload and removal behavior" do
    visit edit_admin_post_path(posts(:one))
    assert_selector "[data-controller='markdown-editor paste-image']"
    original = find("#post_content").value
    find("[data-paste-image-target='fileInput']", visible: :all).attach_file @image.path, make_visible: true
    assert_selector ".image-upload[data-state='uploaded']"
    assert_includes find("#post_content").value, "!["
    find(".image-upload-remove").click
    assert_equal original.strip, find("#post_content").value.strip
    assert_button "保存更改", disabled: false
  end

  test "multiple images serialize once and removal keeps the text unchanged" do
    fill_in "thought_content", with: "正文保持不变"
    find("[data-paste-image-target='fileInput']", visible: :all).attach_file [@image.path, @image.path], make_visible: true
    assert_selector ".image-upload[data-state='uploaded']", count: 2
    assert_equal 2, page.evaluate_script("new FormData(document.querySelector('[data-controller=\"paste-image quick-post\"]')).get('thought[content]')").scan("![").length
    all(".image-upload-remove").first.click
    assert_selector ".image-upload[data-state='uploaded']", count: 1
    assert_equal 1, page.evaluate_script("new FormData(document.querySelector('[data-controller=\"paste-image quick-post\"]')).get('thought[content]')").scan("![").length
    find(".image-upload-remove").click
    assert_no_selector ".image-upload"
    assert_field "thought_content", with: "正文保持不变"
    assert_equal 0, page.evaluate_script("new FormData(document.querySelector('[data-controller=\"paste-image quick-post\"]')).get('thought[content]')").scan("![").length
  end

  test "compresses a photo over the upload limit before sending it and preserves EXIF orientation" do
    photo = Tempfile.new(["large-portrait", ".jpg"])
    noise = (42..44).map { |seed| Vips::Image.gaussnoise(3600, 2400, mean: 128, sigma: 45, seed: seed).cast(:uchar) }
    image = noise.first.bandjoin(noise.drop(1))
    image.set_type(GObject::GINT_TYPE, "orientation", 6)
    photo.binmode
    photo.write(image.jpegsave_buffer(Q: 100, subsample_mode: :off))
    photo.flush
    assert_operator photo.size, :>, 10.megabytes
    received = nil
    convert = WebImage.method(:convert)
    WebImage.define_singleton_method(:convert) do |path, **options|
      decoded = Vips::Image.new_from_file(path)
      received = { bytes: File.size(path), width: decoded.width, height: decoded.height }
      convert.call(path, **options)
    end
    page.execute_script <<~JS
      const encode = HTMLCanvasElement.prototype.toBlob;
      HTMLCanvasElement.prototype.toBlob = function(callback, ...args) {
        HTMLCanvasElement.prototype.toBlob = encode;
        encode.call(this, blob => { window.finishCompression = () => callback(blob) }, ...args);
      };
    JS
    fill_in "thought_content", with: "手机大图"
    find("[data-paste-image-target='fileInput']", visible: :all).attach_file photo.path, make_visible: true
    assert_selector ".image-upload[data-state='compressing']"
    assert_button "压缩中…", disabled: true
    find("#thought_content").send_keys([:control, :enter])
    assert_current_path root_path
    assert_nil received
    Timeout.timeout(10) { sleep 0.05 until page.evaluate_script("typeof window.finishCompression === 'function'") }
    page.execute_script("window.finishCompression()")
    assert_selector ".image-upload[data-state='uploaded']", text: "已压缩", wait: 15
    assert_equal [1280, 1920], received.values_at(:width, :height)
    assert_operator received[:bytes], :<, 2.megabytes
    assert_operator received[:bytes], :<, photo.size / 5
    puts "Phone photo: #{photo.size} bytes -> #{received[:bytes]} uploaded bytes (1280x1920)"
    assert_field "thought_content", with: "手机大图"
    assert_button "发布", disabled: false
  ensure
    WebImage.define_singleton_method(:convert, convert) if convert
    photo&.close!
  end

  test "preserves PNG transparency and skips animated or undecodable images" do
    require "zlib"
    chunk = ->(type, data) { [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N") }
    apng = "\x89PNG\r\n\x1a\n".b
    apng << chunk.call("IHDR", [2, 1, 8, 6, 0, 0, 0].pack("N2C5"))
    apng << chunk.call("tEXt", "Comment\0" + "padding" * 80_000)
    apng << chunk.call("acTL", [2, 0].pack("N2"))
    2.times do |index|
      apng << chunk.call("fcTL", [index * 2, 2, 1, 0, 0, 1, 10, 0, 0].pack("N5n2C2"))
      pixels = Zlib::Deflate.deflate("\0".b + [255, index * 255, 0, 128].pack("C4") * 2)
      apng << chunk.call(index.zero? ? "IDAT" : "fdAT", index.zero? ? pixels : [2].pack("N") + pixels)
    end
    apng << chunk.call("IEND", "")
    alpha = Vips::Image.gaussnoise(2400, 1600, mean: 128, sigma: 45, seed: 42).cast(:uchar)
    png = alpha.bandjoin([alpha, alpha, alpha.new_from_image(90)]).pngsave_buffer
    cases = [
      ["transparent.png", "image/png", png, false],
      ["animated.png", "image/png", apng, true],
      ["animated.gif", "image/gif", "GIF89a" + "x" * 600_000, true],
      ["animated.webp", "image/webp", "RIFF" + "x" * 600_000, true],
      ["unsupported.heic", "image/heic", "not decodable" * 60_000, true]
    ]
    cases.each do |name, type, bytes, unchanged|
      result = page.driver.browser.execute_async_script(<<~JS, name, type, Base64.strict_encode64(bytes))
        const [name, type, encoded, done] = arguments;
        const input = new File([Uint8Array.from(atob(encoded), ch => ch.charCodeAt(0))], name, {type});
        const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller="paste-image quick-post"]'), 'paste-image');
        controller.compressImage(input).then(async output => {
          const result = {same: output === input, size: output.size};
          if (!result.same) {
            const bitmap = await createImageBitmap(output);
            const canvas = document.createElement('canvas');
            canvas.width = canvas.height = 1;
            const context = canvas.getContext('2d');
            context.drawImage(bitmap, 0, 0);
            result.alpha = context.getImageData(0, 0, 1, 1).data[3];
            bitmap.close();
          }
          done(result);
        }).catch(error => done({error: error.message}));
      JS
      assert_equal unchanged, result["same"], name
      if unchanged
        assert_equal bytes.bytesize, result["size"], name
      else
        assert_operator result["size"], :<, bytes.bytesize
        assert_in_delta 90, result["alpha"], 1
      end
    end
  end


  test "removing a photo during compression skips its upload and lets the queue continue" do
    page.execute_script <<~JS
      const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller="paste-image quick-post"]'), 'paste-image');
      const compress = controller.compressImage.bind(controller);
      controller.compressImage = file => {
        controller.compressImage = compress;
        return new Promise(resolve => { window.finishCompression = () => compress(file).then(resolve) });
      };
    JS
    before = ActiveStorage::Blob.count
    find("[data-paste-image-target='fileInput']", visible: :all).attach_file [@image.path, @image.path], make_visible: true
    assert_selector ".image-upload[data-state='compressing']", count: 1
    assert_selector ".image-upload[data-state='queued']", count: 1
    find(".image-upload[data-state='compressing'] .image-upload-remove").click
    assert_button "上传中…", disabled: true
    page.execute_script("window.finishCompression()")
    assert_selector ".image-upload[data-state='uploaded']", count: 1
    assert_equal before + 1, ActiveStorage::Blob.count
    assert_button "发布", disabled: false
  end

  test "an HEIC photo with an empty MIME type reaches the server converter" do
    heic = Vips::Image.black(64, 48).new_from_image([40, 100, 160]).heifsave_buffer(Q: 80)
    page.execute_script(<<~JS, Base64.strict_encode64(heic))
      const data = new DataTransfer();
      data.items.add(new File([Uint8Array.from(atob(arguments[0]), ch => ch.charCodeAt(0))], 'iphone.HEIC', {type: ''}));
      const input = document.querySelector('[data-paste-image-target="fileInput"]');
      input.files = data.files;
      input.dispatchEvent(new Event('change', {bubbles: true}));
    JS
    assert_selector ".image-upload[data-state='uploaded']"
    assert_button "发布", disabled: false
    blob = ActiveStorage::Blob.order(:id).last
    assert_equal "image/webp", blob.content_type
    assert_equal [64, 48], blob.metadata.values_at("width", "height")
  end

end
