class Post < ApplicationRecord
  include MarkdownRenderable
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many_attached :images

  validates :title, presence: true
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published] }
  validates :custom_slug, format: { with: /\A[a-z0-9\-]*\z/, message: "只能包含小写字母、数字和连字符" }, allow_blank: true

  after_save :attach_content_images
  after_save :schedule_image_processing
  before_update :clean_unused_images

  def self.permitted_attributes
    [:title, :content, :status, :tag_list, :custom_slug]
  end

  scope :published, -> { where(status: 'published') }
  scope :drafts, -> { where(status: 'draft') }

  def slug_candidates
    custom_slug.presence || pinyin_title
  end

  def pinyin_title
    PinYin.permlink(title).gsub(/\s+/, '-')
  end

  def should_generate_new_friendly_id?
    custom_slug_changed? || title_changed? || super
  end

  def rendered_content
    markdown_to_html(content)
  end

  def tag_list
    tags.map(&:name).join(', ')
  end

  def tag_list=(names)
    self.tags = names.split(',').map do |name|
      Tag.where(name: name.strip).first_or_create!
    end
  end

  private

  def attach_content_images
    # 从内容中提取所有图片的 blob signed_id
    content.scan(/!\[.*?\]\((\/rails\/active_storage\/blobs\/.*?)\)/) do |url|
      begin
        # 从 URL 中提取 signed_id
        if url[0] =~ /\/rails\/active_storage\/blobs\/(.*?)\//
          signed_id = $1
          # 检查这个 blob 是否存在
          blob = ActiveStorage::Blob.find_signed(signed_id)
          # 如果 blob 存在且还没有被关联到这篇文章，就建立关联
          if blob && !images.blobs.include?(blob)
            images.attach(blob)
          end
        end
      rescue ActiveRecord::RecordNotFound
        # 如果找不到 blob，记录日志但不中断处理
        Rails.logger.warn "Cannot find blob for URL: #{url} in post #{id}"
      end
    end
  end

  def clean_unused_images
    return unless content_changed?

    # 获取当前内容中的所有图片 URL
    current_urls = content.scan(/!\[.*?\]\((\/rails\/active_storage\/blobs\/.*?)\)/).flatten

    # 遍历所有已附加的图片
    images.each do |image|
      # 如果图片的 URL 不在当前内容中，则删除这个附件
      unless current_urls.any? { |url| url.include?(image.signed_id) }
        image.purge_later
      end
    end
  end

  def schedule_image_processing
    return unless content_changed? || saved_change_to_status?

    # 如果文章是发布状态，立即处理图片
    if published?
      ProcessPostImagesJob.perform_later(id)
    end
  end
end
