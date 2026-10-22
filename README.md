# README

CuteERP 是面向小型制造/贸易团队的轻量 ERP：客户订单、六联单（生产订单）、分配台账、
出库、价格管理（含阶梯价）、月度对账、关账与备份，以及美元/人民币双币种支持。

- 技术栈：Ruby 3.3 / Rails 8.1 / PostgreSQL 16 / Propshaft + esbuild / Bootstrap 5
- 迁移自 Rails 3.2/4.2 老系统（升级与功能设计决策见 `docs/feature_plan.md`）

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/setup_wsl.md](docs/setup_wsl.md) | 开发环境快速搭建（WSL2 + Ubuntu 22.04） |
| [docs/features.md](docs/features.md) | 功能总览与操作入口 |
| [docs/architecture.md](docs/architecture.md) | 架构、数据模型、导入体系/预检规则、型号命名规则、**当前状态与快速恢复** |
| [docs/deploy_synology.md](docs/deploy_synology.md) | 群晖 NAS 部署（Docker）与远程访问、备份恢复 |
| [docs/feature_plan.md](docs/feature_plan.md) | 功能升级计划与设计决策 D1–D14（存档） |
| [docs/phase2_plan.md](docs/phase2_plan.md) | 第二阶段计划：对账/备份/Excel 并行（存档） |
| [docs/phase3_plan.md](docs/phase3_plan.md) | 第三阶段计划：核对工作流（待实施） |

> **快速恢复上下文**：新会话先读 [docs/architecture.md](docs/architecture.md) 的
> 「当前状态与快速恢复」章节——含最近交付清单（提交号）、部署固定流程与待办事项。

## 快速开始（开发）

```bash
# 依赖：Ruby 3.3.6、PostgreSQL 16、Node 20 + Yarn（完整步骤见 docs/setup_wsl.md）
bundle install
bin/rails db:prepare
yarn install && yarn build && yarn build:css
bin/rails server -b 0.0.0.0 -p 3000
```

浏览器打开 <http://localhost:3000>（Windows 侧可直接访问 WSL 的 3000 端口）。

## 核心业务流

```
客户订单（草稿→提交→可冲销）
   └─ 分解/签发 → 六联单（草稿→提交，未出库可改）→ 出库（可多次，发货时间=末次出库）
                    └─ 分配台账（D2）：跨订单拆分数量，需求 = 数量 − 冲销 − 已分配
```

价格带成分拆分（芯片 / 声码1 / 声码2，含未税口径 ÷1.13），下单时快照到订单行；
月度导出工作簿、Excel 幂等导入、客户对账单（含未交订单）与关账归档见
[docs/features.md](docs/features.md)。

## 测试

冒烟测试脚本位于 `tmp/check_*.rb`（请求级全链路验证，跑前需开发服务器已停止或另端口）：

```bash
bin/rails runner tmp/check_p3.rb   # 客户订单/六联单/冲销
bin/rails runner tmp/check_p4.rb   # 签发/出库/台账
bin/rails runner tmp/check_p5.rb   # 计划/仪表盘
bin/rails runner tmp/check_ui2.rb  # 页面与快捷流程
```

## 生产测试（3001）

在 WSL 中进入 cute_erp 目录，**每次代码更新后按此固定流程**（缺一步生产端就不生效）：

```bash
bin/rails db:migrate RAILS_ENV=production                              # 有迁移时
yarn build && yarn build:css                                           # 前端改动时
bin/rails assets:precompile RAILS_ENV=production                       # 总是要（刷新指纹清单）
RAILS_ENV=production bin/rails server -b 127.0.0.1 -p 3001             # 重启
```

> 注意：生产端引用 `public/assets` 的带指纹副本，只跑 `yarn build` 不跑
> `assets:precompile` 前端不会更新。凭据见 `config/credentials/production.yml.enc`。

## 部署

- 群晖 NAS：Container Manager 跑 `deploy/docker-compose.yml`（web + postgres:16），
  DSM 反向代理提供 HTTPS 远程访问 —— 见 [docs/deploy_synology.md](docs/deploy_synology.md)
- 备份：`bin/rails cute_erp:backup:daily`（每日，保留 30 天）、
  `bin/rails cute_erp:backup:monthly`（关账归档：pg_dump + 当月工作簿）


## 优化事项

价格批准检查：
当报价高于阶梯报价时，允许批准。
当报价低于阶梯报价时（小于1元），需要PRR框输入PRR号。快捷创建也需要。

客户名被使用，后面像更新更新不了，合理吗？




