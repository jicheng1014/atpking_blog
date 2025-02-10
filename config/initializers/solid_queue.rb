# 配置 Solid Queue 的定时任务
Rails.application.config.solid_queue.cron_jobs do |cron|
  # 每天凌晨 3 点运行清理任务
  cron.add "0 3 * * *", CleanupOrphanedImagesJob

  # 每5分钟处理一次未处理的图片
  cron.add "*/5 * * * *", ProcessPostImagesJob
end
