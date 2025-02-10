class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  class << self
    def get(key)
      setting = find_by(key: key)
      setting&.value
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      setting.update(value: value)
    end

    def site_name
      get('site_name')
    end

    def post_signature
      get('post_signature')
    end

    def icp_number
      get('icp_number')
    end
  end
end
