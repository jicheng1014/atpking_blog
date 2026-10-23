class Comment < ApplicationRecord
  after_commit { PublishStaticSiteJob.enqueue_if_configured }

  belongs_to :post
  belongs_to :user

  validates :content, presence: true
end
