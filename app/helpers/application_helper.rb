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

  def nav_link_class(active)
    base = "text-sm transition-colors"
    active ? "#{base} text-stone-900 font-medium" : "#{base} text-stone-500 hover:text-stone-800"
  end

  def mobile_nav_link_class(active)
    base = "block px-3 py-2 text-sm rounded-md transition-colors"
    active ? "#{base} text-stone-900 font-medium bg-stone-100" : "#{base} text-stone-500 hover:text-stone-800 hover:bg-stone-100"
  end
end
