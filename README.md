# 3Q, Are you ok?



这是 Ruby 4.0.9 / Rails 8.1.4 / SQLite / Solid Queue 博客。公网地址为 https://www.3qruok.com 。

## N305 编辑 + 广州静态站

Ruby 4.0.9 / Rails 8.1.4 后台与 SQLite、规范化 WebP 图片运行在 N305 的 Ubuntu VM。公网 `https://www.3qruok.com` 始终进入广州 ECS；nginx 直接提供发布后的页面、RSS 与图片，`/admin`、`/session`、`/passwords` 和需要登录的未发布图片预览通过 Tailscale 转发。首页 `/` 与灵感列表 `/thoughts`（含末尾斜杠）带 `session_id` Cookie 时也转发 Rails，由 Rails 验证签名和会话后显示原有快捷发布框；无 Cookie 的访客仍读取静态页面。动态页面禁止缓存，静态页面按 Cookie 区分缓存；发布后作者立即看到主库内容，访客等待自动静态发布。浏览器不需要安装 Tailscale。

发布流程：模型提交后 `PublishStaticSiteJob` 串行生成完整站点；图片与资源先传，页面后传；保存 SQLite online-backup、图片备份；接收端校验文件 SHA256 与数据库完整性后原子替换 `current` 链接。失败保留旧版本并重试三次。每天 00:05 刷新日期/月历。草稿保存不外发；已发布文章更新、取消发布、删除均自动重发。后台状态显示进行中、成功时间或失败原因，任务页可重试。

- VM：`/home/atpking/atpking-blog`，`storage/production.sqlite3` 是主数据库，`storage/` 同时保存 Active Storage 图片。
- 广州：`/srv/atpking-blog/releases/<版本>`、`current`、`previous`；`backups/<版本>/production.sqlite3` 是一致性快照，`backups/originals/` 保存图片备份副本，备份路径不挂入公网 URL。
- 主站 nginx 配置：`script/deploy/nginx.conf`；接收端：`script/deploy/blog-receive.py`，仅允许受限 SSH 发布键执行 rsync/activate/rollback，不提供普通 shell。
- 部署环境：`STATIC_SITE_URL=https://www.3qruok.com`、`STATIC_PUBLISH_TARGET=blogdeploy@<广州Tailscale地址>`、`SOLID_QUEUE_IN_PUMA=true`，原 `RAILS_MASTER_KEY` 必须保持不变才能解析历史 signed 图片链接。发布 SSH key 与 known_hosts 位于 VM 的 `deploy/`，权限 600。
- 镜像构建：`docker build --platform linux/amd64 -t atpking-blog:<commit> .`。Ruby 4.0.9 slim tag 未提供时使用官方源码与固定 SHA256 构建，不降级。
- 当前 VM 使用镜像提取的用户态 Ruby/动态库（`runtime/`），由 `bin/ruby` 包装器调用；不需要安装 Docker 或取得 sudo。systemd 用户服务 `atpking-blog.service` 已开启 linger，自启及失败重启。Rails 仅监听 Tailscale `100.64.0.4:3000`；广州 `100.64.0.5` 通过 nginx 转发管理入口。`RAILS_MAX_THREADS=5` 满足内嵌 Solid Queue 连接池需求。旧 Kamal 部署入口已阻止，避免把 Rails 部署回广州。
- 服务管理：VM 上 `systemctl --user restart atpking-blog`；日志 `journalctl --user -u atpking-blog`。生产环境文件为 `../blog.env`，保留原 master key，禁止提交版本库。

上传图片先用 libvips 转为 WebP（最长边 1920、质量 82、自动 EXIF 方向），成功后仅保存规范化图片。已有图片沿用 blob ID/signed ID，更新文件名、校验值和 MIME 后清理旧存储文件；SVG 保留矢量，动画 WebP/GIF 保留帧时长与透明通道。公开旧 `.jpg/.png` URL 不变，nginx 从 `.webp` 旁路文件提供 `image/webp`。静态 HTML 内嵌 24px 低清预览和尺寸，整张清晰图 decode 完成后淡入；首张内容图 eager，其余 lazy；关闭 JavaScript 仍显示普通图片，减少动态效果时不淡入。外部托管的图片无法在本博客内转换。

回滚静态版本：使用发布 SSH key 执行 `ssh blogdeploy@<广州Tailscale地址> rollback <版本>`，会先校验完整性再切换。数据库恢复先 `systemctl --user stop atpking-blog`（不停止整台 VM），从 `backups/<版本>/production.sqlite3` 恢复，删除对应旧 WAL/SHM，再恢复 `backups/originals/` 并验证 `PRAGMA integrity_check` 为 `ok` 后启动。迁移前广州原卷备份单独保留在 `/root/blog-migration-backups/20261023/`。

验证：`bin/rails test test/services/web_image_test.rb test/services/static_site_exporter_test.rb test/integration/blog_test.rb test/integration/static_admin_test.rb test/controllers/admin/settings_controller_test.rb`，以及 `python3 test/deploy_receiver_test.py`。密码重置 token/页面保留，链接使用真实公网域名。

密码重置邮件使用与 OK Uptime 相同的阿里云 SMTP 接入方式：在私有 `blog.env` 配置完整发信邮箱 `SMTP_USER_NAME`、`SMTP_PASSWORD`，可选 `SMTP_ADDRESS`（默认 `smtp.mail.aliyun.com`）与 `MAIL_FROM`（默认使用发信邮箱）。连接使用 465 端口和 TLS，并校验服务器证书。环境文件权限为 0600，禁止提交；修改后重启博客用户服务。SMTP 认证通过仅证明连接和凭据有效，实际邮件送达需单独验收。
