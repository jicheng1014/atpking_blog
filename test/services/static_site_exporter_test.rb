require "test_helper"
require "tmpdir"

class StaticSiteExporterTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("static-export-")
    @release = Pathname(@directory).join("release")
  end

  teardown do
    FileUtils.rm_rf(@directory)
  end

  test "exports public pages, pagination, date filters and RSS without draft data" do
    20.times do |index|
      Post.create!(title: "Article #{index}", custom_slug: "article-#{index}", content: "Public body", status: "published", user: users(:one), tags: [tags(:one)])
    end
    thought = Thought.create!(content: "Public thought", user: users(:one), created_at: 1.month.ago)
    20.times { Thought.create!(content: "Another public thought", user: users(:one), created_at: thought.created_at) }
    Thought.create!(content: "Secret thought", status: "draft", user: users(:one))
    StaticSiteExporter.new(@release).call

    assert page("/posts", page: 2).file?
    assert page("/", page: 2).file?
    assert page("/posts/tag/ruby", page: 2).file?
    assert page("/posts/#{posts(:one).id}").file?
    assert page("/posts/published-article").file?
    assert page("/thoughts/#{thought.slug}").file?
    assert page("/thoughts", month: thought.created_at.strftime("%Y-%m"), date: thought.created_at.to_date.iso8601).file?
    assert page("/thoughts", page: 2, month: thought.created_at.strftime("%Y-%m"), date: thought.created_at.to_date.iso8601).file?
    refute page("/posts/private-draft").exist?
    refute page("/tags/rails").exist?
    refute_includes page("/tags").read, "Rails</span>"
    html = @release.glob("pages/**/*.html").map(&:read).join
    refute_includes html, "Private draft"
    refute_includes html, "Unpublished content"
    refute_includes html, "Secret thought"
    refute_includes html, "/admin/posts/new"
    assert_equal page("/posts/feed").read, page("/posts/feed.rss").read
    assert_includes page("/posts/feed").read, "https://www.3qruok.com/posts/"
    assert_includes page("/posts/tag/ruby", page: 2).read, '/posts/tag/ruby"'
  end

  test "copies only referenced images byte for byte at proxy redirect and legacy paths" do
    bytes = "original image bytes\x00\xff".b
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "image space.png", content_type: "image/png")
    draft_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("draft private image"), filename: "private.png", content_type: "image/png")
    urls = ["proxy/", "redirect/", ""].map { |prefix| "/rails/active_storage/blobs/#{prefix}#{blob.signed_id}/image%20space.png" }
    posts(:one).update_columns(content: "![Markdown](#{urls.first})\n<img src=\"#{urls[1]}\"><img src=\"#{urls[2]}\">")
    private_url = "/rails/active_storage/blobs/proxy/#{draft_blob.signed_id}/private.png"
    posts(:two).update_columns(content: "![private](#{private_url})")
    StaticSiteExporter.new(@release).call

    urls.each { |url| assert_equal bytes, @release.join(URI.decode_www_form_component(url).delete_prefix("/")).binread }
    refute @release.join(private_url.delete_prefix("/")).exist?
    ProcessPostImagesJob.perform_now(posts(:one).id)
    assert_equal bytes, blob.download
  ensure
    blob&.purge
    draft_blob&.purge
  end

  test "legacy uploads are copied only when published content references them" do
    upload = Rails.root.join("public/uploads", "static-export-#{SecureRandom.hex(6)}.png")
    upload.dirname.mkpath
    upload.binwrite("original upload")
    posts(:one).update_columns(content: "![upload](/uploads/#{upload.basename})")
    StaticSiteExporter.new(@release).call
    assert_equal "original upload", @release.join("uploads", upload.basename).binread
    assert_equal [upload.basename.to_s], @release.join("uploads").children.map { |path| path.basename.to_s }
  ensure
    upload&.delete if upload&.exist?
  end

  test "missing published image aborts export" do
    posts(:one).update_columns(content: '<img src="/uploads/missing-export-test.png">')
    assert_match(/Missing upload/, assert_raises(RuntimeError) { StaticSiteExporter.new(@release).call }.message)
  end

  test "decoded traversal in image URL aborts export" do
    posts(:one).update_columns(content: '<img src="/uploads/%2e%2e/secret">')
    assert_match(/Unsafe export path/, assert_raises(ArgumentError) { StaticSiteExporter.new(@release).call }.message)
  end

  test "failed export never calls publishing transport" do
    previous_target = ENV["STATIC_PUBLISH_TARGET"]
    ENV["STATIC_PUBLISH_TARGET"] = "unused-test-target"
    posts(:one).update_columns(content: '<img src="/uploads/missing-export-test.png">')
    job = PublishStaticSiteJob.new
    job.define_singleton_method(:system) { |*| flunk "Transport must not run after export failure" }
    assert_match(/Missing upload/, assert_raises(RuntimeError) { job.perform }.message)
  ensure
    ENV["STATIC_PUBLISH_TARGET"] = previous_target
  end

  private

  def page(path, page: 1, month: "", date: "")
    @release.join("pages#{path.delete_suffix('/')}", "index.p#{page}.m#{month}.d#{date}.html")
  end
end
