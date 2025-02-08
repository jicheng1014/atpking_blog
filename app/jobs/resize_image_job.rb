class ResizeImageJob < ApplicationJob
  # 这个 Job 已经不再需要了，我们将使用 ActiveStorage 的 variant 功能
  # 保留这个文件是为了确保没有遗留的任务在队列中
  queue_as :default

  def perform(blob)
    # 不执行任何操作
  end
end
