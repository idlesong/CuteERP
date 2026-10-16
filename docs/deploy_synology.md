# 群晖 NAS 部署（Container Manager / Docker）

> 适用：DSM 7.x + Container Manager 套件；4GB 内存以上机型。
> 应用以 Docker 容器运行（web + postgres:16），通过 DSM 反向代理提供 HTTPS 远程访问。

## 1. 准备文件

把项目推送到 NAS 可访问的位置（git clone 或 File Station 上传），至少包含：

```
cute_erp/
├── deploy/Dockerfile
├── deploy/docker-compose.yml
└── （完整项目源码，deploy/Dockerfile 在镜像构建时 COPY 项目）
```

> 注意：compose 的 `build.context` 指向项目根目录，因此建议整个项目目录上传，
> `deploy/docker-compose.yml` 里用 `context: ..`、`dockerfile: deploy/Dockerfile`。

## 2. 密钥与配置

```bash
# 在任意装有 ruby 的机器上生成（或 docker run ruby:3.3 bin/rails secret）
RAILS_MASTER_KEY=<生成的32字节密钥>
```

写入 NAS 上 `cute_erp/deploy/.env`（与 compose 同目录，勿提交到仓库）：

```ini
RAILS_MASTER_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
POSTGRES_PASSWORD=<数据库密码>
```

## 3. 构建并启动

Container Manager → 项目 → 新增 → 选择 `deploy/docker-compose.yml` → 启动。
或 SSH 到 NAS：

```bash
cd /volume1/docker/cute_erp/deploy
docker compose up -d --build
docker compose logs -f web        # 看到 Listening on 0.0.0.0:3000 即成功
```

数据位置（建议映射到共享文件夹，便于快照）：

| 容器内 | NAS 共享文件夹 | 内容 |
|---|---|---|
| /var/lib/postgresql/data | docker/cute_erp/db | 数据库 |
| /app/storage | docker/cute_erp/storage | 附件 + pg_dump/工作簿归档 |

## 4. 远程访问（HTTPS）

**推荐：DSM 反向代理 + DDNS + Let's Encrypt**

1. 控制面板 → 外部访问 → DDMS/DDNS：注册群晖 DDNS 或填自有域名
2. 控制面板 → 安全性 → 证书：为该域名申请 Let's Encrypt 证书
3. 控制面板 → 登录门户 → 高级 → 反向代理：
   - 来源：HTTPS，443，主机名 `erp.你的域名`
   - 目的地：HTTP，`localhost`，3000
4. （可选）在 `config/environments/production.rb` 开启 `config.force_ssl = true` 后重建镜像

远程设备浏览器访问 `https://erp.你的域名` 即可。

**替代方案**：群晖 VPN Server（WireGuard）连入后按局域网方式访问 3000 端口；
或用 Tailscale/frp 等组网容器。不要把 3000 端口直接暴露，务必走 HTTPS。

## 5. 备份与恢复（D13）

内置两条 rake 任务（容器内执行，`docker compose exec web ...`）：

```bash
bin/rails cute_erp:backup:daily     # 每日兜底 pg_dump，保留 30 天
bin/rails cute_erp:backup:monthly   # 月度归档：pg_dump + 当月工作簿
```

在 Container Manager 或 DSM「任务计划」添加每日任务，例如：

```bash
cd /volume1/docker/cute_erp/deploy && docker compose exec -T web bin/rails cute_erp:backup:daily
```

**恢复演练（建议每季度做一次）**：

```bash
# 空库或目标库上
gunzip -c cute_erp_closed_202610.sql.gz | \
  docker compose exec -T db psql -U cute_erp cute_erp_production
```

恢复语义（D13）：灾难 = 整库恢复到归档点；账务纠错 = 重开月份修单或冲销，不做单月回灌。

## 6. 日常运维

| 操作 | 命令/入口 |
|---|---|
| 升级版本 | git pull 后 `docker compose up -d --build` |
| 查看日志 | Container Manager → 项目 → web → 日志（或 `docker compose logs -f web`） |
| 控制台 | `docker compose exec -T web bin/rails console` |
| 关账归档 | 更多 → 关账与归档（页面操作，自动归档） |
| 导入/导出 | 更多 → 导入 / 导出当月 |
