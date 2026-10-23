# 3Q, Are you ok?



这是一个基于 Rails 8.1 的博客系统，使用 Kamal 部署。

目前 作者自己通过这个 blog 的地址是 [https://www.3qruok.com](https://www.3qruok.com)


## 技术栈

- Ruby 4.0.9 / Rails 8.1.4
- sqlite
- solid_queue
- kamal2


## 部署

```bash
kamal deploy
```

部署后 是用 rails console 建立管理员用户

```bash
kamal console

user = User.new
user.email = 'admin@example.com'
user.password = 'password'
user.save!
```

## N305 编辑 + 广州静态站

Ruby 4.0.9 / Rails 8.1.4 后台与 SQLite、图片原文件运行在 N305 的 Ubuntu VM。公网 `https://www.3qruok.com` 始终进入广州 ECS；nginx 直接提供发布后的页面、RSS 与图片，仅 `/admin`、`/session`、`/passwords` 和需要登录的未发布图片预览通过 Tailscale 转发。浏览器不需要安装 Tailscale。

发布流程：模型提交后 `PublishStaticSiteJob` 串行生成完整站点；图片与资源先传，页面后传；保存 SQLite online-backup、原图备份；接收端校验文件 SHA256 与数据库完整性后原子替换 `current` 链接。失败保留旧版本并重试三次。每天 00:05 刷新日期/月历。草稿不导出；图片原始数据不再被旧压缩任务覆盖。

- VM：`/home/atpking/atpking-blog`，`storage/production.sqlite3` 是主数据库，`storage/` 同时保存 Active Storage 原图。
- 广州：`/srv/atpking-blog/releases/<版本>`、`current`、`previous`；`backups/<版本>/production.sqlite3` 是一致性快照，`backups/originals/` 保存原图副本，备份路径不挂入公网 URL。
- 主站 nginx 配置：`script/deploy/nginx.conf`；接收端：`script/deploy/blog-receive.py`，仅允许受限 SSH 发布键执行 rsync/activate/rollback，不提供普通 shell。
- 部署环境：`STATIC_SITE_URL=https://www.3qruok.com`、`STATIC_PUBLISH_TARGET=blogdeploy@<广州Tailscale地址>`、`SOLID_QUEUE_IN_PUMA=true`，原 `RAILS_MASTER_KEY` 必须保持不变才能解析历史 signed 图片链接。发布 SSH key 与 known_hosts 只读挂载到 `/rails/deploy/`。
- 镜像构建：`docker build --platform linux/amd64 -t atpking-blog:<commit> .`。Ruby 4.0.9 slim tag 未提供时使用官方源码与固定 SHA256 构建，不降级。
- 容器只将 Rails 3000 端口绑定至 VM 的 Tailscale 地址及 loopback；不暴露到公网。旧 Kamal 部署入口已加阻止保护，避免把 Rails 重新部署到广州。

回滚静态版本：使用发布 SSH key 执行 `ssh blogdeploy@<广州Tailscale地址> rollback <版本>`，会先校验完整性再切换。数据库恢复先停止博客容器（不停止整台 VM），从 `backups/<版本>/production.sqlite3` 恢复，删除对应旧 WAL/SHM，再恢复 `backups/originals/` 并验证 `PRAGMA integrity_check` 为 `ok` 后启动。迁移前广州原卷备份单独保留在 `/root/blog-migration-backups/20261023/`。

验证：`bin/rails test test/services/static_site_exporter_test.rb test/integration/blog_test.rb test/integration/static_admin_test.rb test/controllers/admin/settings_controller_test.rb`，以及 `python3 test/deploy_receiver_test.py`。密码重置 token/页面保留，链接使用真实公网域名；原项目尚未配置真实 SMTP 与发信地址，邮件交付需指定发信账号后配置。
