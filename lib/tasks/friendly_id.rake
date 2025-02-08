namespace :friendly_id do
  desc "重新生成所有文章的 friendly_id slugs"
  task regenerate: :environment do
    puts "开始重新生成文章 slugs..."
    Post.find_each do |post|
      puts "处理文章: #{post.title}"
      post.slug = nil
      post.save
    end
    puts "完成！"
  end
end
