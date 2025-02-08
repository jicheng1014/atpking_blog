# 3Q, Are you ok?



这是一个基于 rails 8.0 的博客系统，使用 kamal 部署。

目前 作者自己通过这个 blog 的地址是 [https://www.3qruok.com](https://www.3qruok.com)


## 技术栈

- ruby on rails 8 (base on ruby 3.2)
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
