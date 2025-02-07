xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Are YOU OK?  --from atpking"
    xml.description "分享技术和生活的点点滴滴"
    xml.link root_url
    xml.language "zh-CN"

    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.description post.rendered_content
        xml.pubDate post.created_at.to_fs(:rfc822)
        xml.link post_url(post)
        xml.guid post_url(post)

        post.tags.each do |tag|
          xml.category tag.name
        end
      end
    end
  end
end
