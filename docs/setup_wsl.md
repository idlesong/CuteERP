# 开发环境搭建（WSL2 + Ubuntu 22.04）

> 本项目在 WSL2 Ubuntu-22.04 上开发验证，Windows 侧通过 `localhost:3000` 直接访问。

## 1. 系统依赖

```bash
sudo apt update
sudo apt install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libpq-dev postgresql postgresql-contrib
```

## 2. Ruby 3.3.6（rbenv）

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
exec $SHELL

rbenv install 3.3.6      # 若下载缓慢：提前下载 ruby-3.3.6.tar.xz 放入
                         # ~/.rbenv/cache/ 后重试
rbenv global 3.3.6
gem install bundler
```

> 国内镜像加速（可选）：`bundle config mirror.https://rubygems.org https://mirrors.aliyun.com/rubygems/`

## 3. Node 20 + Yarn

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn
```

## 4. PostgreSQL 16

Ubuntu 22.04 自带 PostgreSQL 14，建议加装 PGDG 源装 16：

```bash
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
  https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
  http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update && sudo apt install -y postgresql-16

sudo -u postgres psql -c "CREATE USER rorweberp WITH PASSWORD 'rorweberp' CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE cute_erp_development OWNER rorweberp;"
```

数据库连接配置在 `config/database.yml`（开发库用户/密码与上面一致即可）。

## 5. 安装项目

```bash
cd ~/design/cute_erp
bundle install
bin/rails db:prepare          # 建库 + 跑全部迁移
yarn install
yarn build && yarn build:css  # 构建 JS/CSS（开发时可改用 yarn dev 监听）
```

## 6. 启动

```bash
bin/rails server -b 0.0.0.0 -p 3000
# Windows 浏览器访问 http://localhost:3000
```

前端改动的两种方式：

- 日常只改 Ruby 代码：`bin/rails s` 即可
- 改 JS/CSS：`bin/dev`（foreman 同时跑 server + esbuild/sass 监听，**二选一不要同时开**）

### 常见坑

| 现象 | 处理 |
|---|---|
| 跑完 `db:migrate` 后运行中的服务报"未知列" | 重启一次服务（schema 缓存不热更新） |
| 新增模型/服务文件报 `uninitialized constant` | 同上，重启服务 |
| `bin/dev` 后台运行 | `nohup bin/dev > /tmp/dev.log 2>&1 &` 或用 tmux；WSL 所有终端关闭会回收后台进程 |

## 7. 冒烟测试

```bash
for f in check_formula check_p2_pages check_p3 check_p4 check_p5 check_ui check_ui2; do
  bin/rails runner tmp/$f.rb
done
```

全部以 `*_CHECK_DONE` 结尾为通过（会创建/清理 `CHxx` 前缀的测试数据）。
