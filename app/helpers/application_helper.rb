module ApplicationHelper
  include Pagy::Frontend

  # 从 thought 的渲染 HTML 中提取图片 URL 列表和纯文本内容
  def extract_thought_parts(rendered_html)
    doc = Nokogiri::HTML.fragment(rendered_html)
    images = doc.css("img").map { |img| img["src"] }
    doc.css("img").each(&:remove)
    text = strip_tags(doc.to_html).squish
    { images: images, text: text }
  end

  # 将 Active Storage blob URL 转为缩略图 variant URL（首次访问时按需生成并缓存）
  # fill: 填充尺寸（像素），默认 160 以覆盖 2× retina 下的 80px 展示
  def thought_thumbnail_url(src, fill: 160)
    if src =~ /\/rails\/active_storage\/blobs\/([^\/]+)\//
      blob = ActiveStorage::Blob.find_signed($1)
      return url_for(blob.variant(resize_to_fill: [fill, fill])) if blob&.image?
    end
    src
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    src
  end

  def nav_link_class(active)
    base = "text-sm transition-colors"
    active ? "#{base} text-stone-900 font-medium" : "#{base} text-stone-500 hover:text-stone-800"
  end

  def mobile_nav_link_class(active)
    base = "block px-3 py-2 text-sm rounded-md transition-colors"
    active ? "#{base} text-stone-900 font-medium bg-stone-100" : "#{base} text-stone-500 hover:text-stone-800 hover:bg-stone-100"
  end
end
