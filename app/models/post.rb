class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published] }

  scope :published, -> { where(status: 'published') }
  scope :drafts, -> { where(status: 'draft') }
end
