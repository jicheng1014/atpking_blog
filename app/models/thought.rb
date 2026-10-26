class Thought < Post
  IMAGE_MAX_DIMENSION = 480
  UPLOAD_MAX_SIZE = 5.megabytes

  before_validation :generate_title, on: :create
  before_save :record_first_publication

  attribute :status, :string, default: 'published'

  def slug_candidates
    custom_slug.presence || "thought-#{created_at_or_now.strftime('%Y%m%d-%H%M%S')}"
  end

  def publication_time
    published_at || created_at
  end

  private

  def record_first_publication
    self.published_at ||= Time.current if published?
  end

  def generate_title
    self.title = created_at_or_now.strftime("%Y年%-m月%-d日 %H:%M 的灵感")
  end

  def created_at_or_now
    created_at || Time.current
  end
end
