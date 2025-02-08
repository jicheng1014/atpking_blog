class Post < ApplicationRecord
  include MarkdownRenderable
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags

  validates :title, presence: true
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published] }
  validates :custom_slug, format: { with: /\A[a-z0-9\-]*\z/, message: "只能包含小写字母、数字和连字符" }, allow_blank: true

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
end
