# N305 用户态运行时

这些文件直接读回自已验收的 N305 Ubuntu VM；不含密钥或环境变量值。用途是在不能安装系统 Ruby/Docker 时，复用本项目生产镜像中的 Ruby、gems、SQLite 和共享库。

固定安装目录为 `/home/atpking/atpking-blog`，目标平台为 Linux x86_64。变更目录时同步修改三个 wrapper 和 service 中的绝对路径。Ruby wrapper 显式调用镜像的动态加载器，避免宿主 Ubuntu 与镜像的 glibc 版本差异；不要把这些私有系统库加入全局 `LD_LIBRARY_PATH`。

## 从生产镜像重建

先按项目 Dockerfile 构建已验证的生产镜像 `atpking-blog-static:release`。在可运行 Docker 的机器上执行以下命令；创建的容器仅供读取，不需要启动：

```sh
runtime_container=$(docker create atpking-blog-static:release)
mkdir -p portable-runtime
docker cp "$runtime_container:/usr/local" portable-runtime/local
docker cp "$runtime_container:/usr/lib/x86_64-linux-gnu" portable-runtime/system-libs
docker cp "$runtime_container:/usr/bin/sqlite3" portable-runtime/sqlite3
docker rm "$runtime_container"

# 不打包开发头文件、旧版 libruby 或 macOS 扩展属性。
COPYFILE_DISABLE=1 tar --no-xattrs -czf portable-runtime.tar.gz \
  --exclude='local/include' --exclude='local/lib/libruby.so.4.0.1' \
  -C portable-runtime local system-libs sqlite3
```

当前运行时源于 Ruby 4.0.9 / Rails 8.1.4 镜像，解压约 394MB。部署前先用 `df -h /` 核对实际可用空间，另留应用、图片、SQLite WAL、临时导出和日志余量。流式解压可避免在 VM 同时保留压缩包：

```sh
ssh local_ubuntu_virt 'mkdir -p /home/atpking/atpking-blog/runtime /home/atpking/atpking-blog/bin'
ssh local_ubuntu_virt 'tar --no-same-owner -xzf - -C /home/atpking/atpking-blog/runtime' < portable-runtime.tar.gz
ssh local_ubuntu_virt 'ln -sfn system-libs /home/atpking/atpking-blog/runtime/x86_64-linux-gnu'
scp script/deploy/native/ruby script/deploy/native/bundle script/deploy/native/sqlite3 \
  local_ubuntu_virt:/home/atpking/atpking-blog/bin/
scp script/deploy/native/runtime-check.rb local_ubuntu_virt:/home/atpking/atpking-blog/
```

`VIPSHOME` 通过 `x86_64-linux-gnu` 链接定位 libvips 模块，`LIBHEIF_PLUGIN_PATH` 定位已有 HEVC 解码插件；缺少这些路径时，普通 JPEG 上传仍能工作，但 HEIC 无法转换。无需另装图片处理库。

已有运行时升级时，先在单独目录验证，停止博客服务后保留旧运行时并切换；不要覆盖正在运行的共享库。原始生产数据库、storage、uploads、环境文件和部署密钥沿用已有持久目录，不从镜像恢复覆盖。

## 验证与服务

在 VM 执行：

```sh
export PATH=/home/atpking/atpking-blog/bin:$PATH
chmod +x /home/atpking/atpking-blog/bin/ruby /home/atpking/atpking-blog/bin/bundle /home/atpking/atpking-blog/bin/sqlite3
ruby /home/atpking/atpking-blog/runtime-check.rb
cd /home/atpking/atpking-blog/app
BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=1 bundle check
```

`runtime-check.rb` 检查 Ruby 版本、标准库、关键原生扩展、SQLite 内存数据库与 BCrypt。当前程序版本变更时同步更新版本断言。

服务读取已有 `/home/atpking/atpking-blog/blog.env`，其权限应为 0600。生产配置要求 `RAILS_ENV=production`、`SOLID_QUEUE_IN_PUMA=1`、`JOB_CONCURRENCY=1`、`RAILS_MAX_THREADS=5`，以及既有 Rails 解密密钥和静态发布配置；不要把环境文件或部署私钥提交到仓库。现有 worker 为 3 线程，数据库连接池至少需要 5。

```sh
scp script/deploy/native/atpking-blog.service local_ubuntu_virt:/home/atpking/.config/systemd/user/
ssh local_ubuntu_virt 'systemd-analyze --user verify ~/.config/systemd/user/atpking-blog.service'
ssh local_ubuntu_virt 'systemctl --user daemon-reload; systemctl --user enable --now atpking-blog.service'
ssh local_ubuntu_virt 'curl -fsS http://100.64.0.4:3000/up; systemctl --user status atpking-blog.service --no-pager'
```

VM 已有 `Linger=yes`，用户服务可脱离 SSH 运行并随开机启动；新机器需管理员启用 linger。失败后每 5 秒重试，等待 Tailscale 地址就绪。Puma 内的 Solid Queue supervisor、dispatcher、worker、scheduler 随服务生命周期启动与优雅停止。`UMask=0077` 保护私有文件，公开发布脚本负责公开目录及文件权限。

这些命令只涉及博客自己的用户目录和 `atpking-blog.service`，不需要停止 OpenClaw。
