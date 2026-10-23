require "uri"
require "rack/mock"
require "set"

class StaticSiteExporter
  def initialize(destination, base_url: ENV.fetch("STATIC_SITE_URL", "https://www.3qruok.com"))
    @root = Pathname(destination).expand_path
    @base_url = URI(base_url)
    raise ArgumentError, "Expected an http(s) site URL" unless %w[http https].include?(@base_url.scheme) && @base_url.host
    @resources = Set.new
  end

  def call
    raise ArgumentError, "Export destination must be new" if @root.exist?
    @root.mkpath
    copy_assets
    export_pages
    @resources.each { |url| copy_resource(url) }
    @root
  end

  private

  def export_pages
    posts = Post.only_posts.status_published
    paginated("/", posts.count)
    paginated("/posts", posts.count)
    export("/tags")
    Post.status_published.find_each do |post|
      prefix = post.thought? ? "/thoughts" : "/posts"
      export("#{prefix}/#{ERB::Util.url_encode(post.to_param)}")
      export("#{prefix}/#{post.id}")
    end
    Tag.joins(:posts).where(posts: { status: "published" }).distinct.find_each do |tag|
      export("/tags/#{ERB::Util.url_encode(tag.to_param)}")
      export("/tags/#{tag.id}")
      paginated("/posts/tag/#{ERB::Util.url_encode(tag.slug)}", tag.posts.only_posts.status_published.count)
    end
    export_thoughts
    rss = render("/posts/feed.rss")
    write("/posts/feed", rss)
    write("/posts/feed.rss", rss)
  end

  def export_thoughts
    dates = Thought.status_published.pluck(:created_at).map(&:to_date).tally
    paginated("/thoughts", dates.values.sum)
    current = Date.current.beginning_of_month
    month = [ dates.keys.min&.beginning_of_month || current, current ].min
    while month <= current
      paginated("/thoughts", dates.values.sum, month: month.strftime("%Y-%m"))
      month += 1.month
    end
    dates.each do |date, count|
      paginated("/thoughts", count, date: date.iso8601)
      paginated("/thoughts", count, month: date.strftime("%Y-%m"), date: date.iso8601)
      # Date-only links retain today's heatmap, whose pagination adds the current month.
      paginated("/thoughts", count, month: current.strftime("%Y-%m"), date: date.iso8601) unless date.beginning_of_month == current
    end
  end

  def paginated(path, count, **filters)
    (1..[ (count / 20.0).ceil, 1 ].max).each do |page|
      export("#{path}?#{filters.merge(page: page).to_query}")
    end
  end

  def export(url)
    html = render(url)
    document = Nokogiri::HTML(html)
    image_index = 0
    document.css("img").each do |node|
      match = node["src"].to_s.match(%r{/rails/active_storage/blobs/(?:proxy/|redirect/)?([^/]+)/})
      next unless match
      blob = ActiveStorage::Blob.find_signed!(match[1])
      WebImage.normalize!(blob)
      if blob.metadata["lqip"]
        node["data-lqip"] = blob.metadata["lqip"]
        node["width"] = blob.metadata["width"].to_s
        node["height"] = blob.metadata["height"].to_s
        node["loading"] = image_index.zero? ? "eager" : "lazy"
        image_index += 1
        node["decoding"] = "async"
        wrapper = Nokogiri::XML::Node.new("span", document)
        wrapper["class"] = "progressive-image"
        card = node["class"].to_s.split.include?("h-full")
        wrapper["class"] += " progressive-image-card" if card
        wrapper["style"] = "background-image:url(#{blob.metadata['lqip']});"
        wrapper["style"] += "aspect-ratio:#{blob.metadata['width']}/#{blob.metadata['height']};" unless card
        node.replace(wrapper)
        wrapper.add_child(node)
      end
    end
    document.css("[src], [href], [poster]").each do |node|
      %w[src href poster].each { |attribute| @resources << node[attribute] if node[attribute] }
    end
    document.css("[srcset]").each do |node|
      node["srcset"].split(",").each { |source| @resources << source.strip.split.first }
    end
    write(url, document.to_html)
  end

  def render(url)
    # A fresh Rack request has no admin cookies. Clear Current even when called from a request/job.
    Current.set(session: nil) do
      env = Rack::MockRequest.env_for(URI.join(@base_url.to_s, url).to_s,
        "HTTP_ACCEPT" => url.end_with?(".rss") ? "application/rss+xml" : "text/html")
      status, _headers, body = Rails.application.call(env)
      begin
        raise "Static render failed (#{status}): #{url}" unless status == 200
        result = +""
        body.each { |chunk| result << chunk }
        result
      ensure
        body.close if body.respond_to?(:close)
      end
    end
  end

  def write(url, content)
    uri = URI(url)
    filters = URI.decode_www_form(uri.query.to_s).to_h
    page = filters.fetch("page", "1")
    month = filters.fetch("month", "")
    date = filters.fetch("date", "")
    relative = "pages#{URI.decode_www_form_component(uri.path).delete_suffix('/')}/index.p#{page}.m#{month}.d#{date}.html"
    target = safe_path(@root, relative)
    target.dirname.mkpath
    target.binwrite(content)
  end

  def copy_assets
    assets = Rails.root.join("public/assets")
    raise "Precompile assets before exporting" unless assets.directory?
    FileUtils.cp_r(assets, @root.join("assets"))
    %w[robots.txt icon.png icon.svg 404.html].each do |name|
      source = Rails.root.join("public", name)
      FileUtils.cp(source, @root.join(name)) if source.file?
    end
  end

  def copy_resource(url)
    uri = URI.parse(url)
    return if uri.host && uri.host != @base_url.host
    path = URI.decode_www_form_component(uri.path.to_s)
    return unless path.start_with?("/rails/active_storage/", "/uploads/")

    target = safe_path(@root, path.delete_prefix("/"))
    target.dirname.mkpath
    if path.start_with?("/uploads/")
      source = safe_path(Rails.root.join("public"), path.delete_prefix("/"))
      raise "Missing upload: #{path}" unless source.file?
      # Resolve symlinks too: a content URL must never copy private files.
      raise "Upload outside public/uploads" unless source.realpath.to_s.start_with?(Rails.root.join("public/uploads").realpath.to_s + "/")
      FileUtils.cp(source, target)
    else
      match = path.match(%r{\A/rails/active_storage/blobs/(?:proxy/|redirect/)?([^/]+)/[^/]+\z})
      raise "Unsupported Active Storage URL: #{path}" unless match
      blob = ActiveStorage::Blob.find_signed!(match[1])
      WebImage.normalize!(blob)
      target = Pathname("#{target}.webp") if blob.content_type == "image/webp"
      target.open("wb") { |file| blob.download { |chunk| file.write(chunk) } }
    end
  rescue URI::InvalidURIError
    raise "Invalid published resource URL: #{url}" if url.include?("/rails/active_storage/") || url.include?("/uploads/")
  end

  def safe_path(root, relative)
    raise ArgumentError, "Unsafe export path" if relative.include?("\0") || relative.split("/").any? { |part| %w[. ..].include?(part) }
    path = root.join(relative).expand_path
    raise ArgumentError, "Path outside export root" unless path.to_s.start_with?(root.expand_path.to_s + "/")
    path
  end
end
