class Tag < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :post_tags, dependent: :destroy
  has_many :posts, through: :post_tags

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: :name_changed?

  private

  def generate_slug
    self.slug = if name.blank?
      ''
    else
      PinYin.permlink(name).presence || SecureRandom.hex(4)
    end
  end
end
