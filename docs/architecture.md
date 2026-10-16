# 架构与代码实现

## 技术栈

| 层 | 选型 | 说明 |
|---|---|---|
| 框架 | Rails 8.1（Ruby 3.3） | 传统服务端渲染单栈（无前后端分离） |
| 数据库 | PostgreSQL 16 | 唯一持久层；无缓存队列等附加服务 |
| 前端 | Propshaft + esbuild + Bootstrap 5 + jQuery + DataTables 3 | Turbo 轻量使用；交互多为传统表单 + 局部脚本 |
| Excel | roo（读）/ caxlsx（写） | 月度工作簿与导入导出 |
| PDF | wicked_pdf（wkhtmltopdf） | 发票 / 装箱单 / 六联单打印 |

## 代码结构（关键目录）

```
app/
├── models/            # ActiveRecord 模型 + concerns（ClosedPeriodGuard/DocumentAttachment）
├── queries/           # 读模型/查询对象：DemandQuery、RevenueQuery、
│                      # SalesOverviewQuery、MonthlyStatement
├── services/          # MonthlyWorkbook（导出）、CustomerOrdersImport、
│                      # SalesOrdersImport、BackupService
├── controllers/       # 按业务域划分；列表页统一 DataTables + 底部快速创建行
└── views/             # 共享局部模板（orders/_lines_table、sales_orders/_orders_table）
```

## 数据模型（业务表）

```
customers ──┬── prices ──┐                    # 报价：客户×通用型号×档位，成分三列+币别+生效期
items ──────┘            │                    # 产品：通用型号+后缀=完整型号；extra_item=声码组件
                         ▼
orders ── order_lines ───┘                   # 客户订单：po_number 唯一；行=po+line_no 唯一
  │        │          （kind: normal/return，status: draft/submitted）
  │        ├── refer_order_line_id            # 冲销行（数量为负）引用原行（D1）
  │        └── base/v1/v2_price               # 价格快照（下单时点）
  │
  └── production_allocations ──► production_lines ──► sales_orders
       分配台账（D2）              六联单行              # serial_number=XS{yyyy}-{流水} 唯一
       （跨订单拆量）              （item=转产定型）      # status: draft/submitted
                                        │
                                        └── shipment_lines ──► shipments
                                             出库明细           # 可多次出库；delivery_date 派生

exchange_rates                              # 按月汇率（多币种折算，D9）
sales_plan_entries                          # 年度销售计划（FY 止年，D12 前置）
imports / closed_periods                    # 导入批次 / 关账月（2.2、2.4）
```

## 核心口径（全系统统一）

| 口径 | 公式 | 实现位置 |
|---|---|---|
| 净需求 | 订单量 − 冲销 − 已分配 | `DemandQuery`（签发池/工作台） |
| 可分配余额 | 净需求 − 已分配 | `OrderLine#allocatable_qty` |
| 已出货（订单行，对账） | 分配比例 × 生产行出库 之和 | `OrderLine#delivered_qty` |
| 未交订单 | 数量 − 冲销 − 已出货 | `OrderLine#open_qty`、对账单 Backlog |
| 营业额（折 RMB） | 出库数量 × 台账加权单价 × 当月汇率 | `RevenueQuery` |
| 生效价格 | approved/active 且在生效期内 | `Price.available / #effective?` |
| 未税金额 | 含税 ÷ 1.13 | `MonthlyWorkbook::TAX_FACTOR` |

## 关键设计决策（详见 docs/feature_plan.md D1–D14）

- **D1 冲销 = 单据类型**：`orders.kind = return`，负数量行引用原行，数量 ≤ 可冲销余额
- **D2 分配台账**：六联单行与客户订单行多对多（production_allocations），
  替代旧的签发购物车与 quantity_issued 字段；需求/余额全部由台账聚合派生
- **D3 三成分固定列**：价格与订单行均为 base/v1/v2 三列（芯片/声码1/声码2）
- **D4 型号 = 通用型号 + 后缀**：无 partNo 列；转产时六联单行确定后缀（同 generic 组选或新建）
- **D9 多币种**：币别在客户上；订单/六联单创建时快照当月汇率；报表按出货月折算
- **D12 关账同包**；**D13 不做单月回灌**（恢复=整库归档点）；**D14 过渡期 Excel 为准**
- **六联单状态机**：草稿（不占需求池）→ 提交（占池、可出库）→ 已出库（行冻结，减少走冲销）
- **客户订单状态机**：草稿 → 提交（ODM 须最终客户）→ 未签发可随意改 → 签发后走冲销

## 交互约定（列表页统一模式）

- 每表：标题行 + **筛选行**（DataTables 注入）+ tfoot **快速创建行**（创建按钮固定在最后操作列）
- 选择型字段用下拉（型号/价格/档位），价格选项按客户+型号过滤并自动选中唯一价
- 行内编辑：`?edit_id=` 行级编辑模式；下载链接一律 `data: { turbo: false }`
- flash 用右下角 toast（通知自动消失，错误常驻）
- 工具栏（高级创建/导出/导入）固定在页面最下方一行

## 测试

`tmp/check_*.rb` 为请求级全链路冒烟（覆盖 P2 公式、P3 订单/冲销、P4 签发出库台账、
P5 计划/仪表盘、UI 交互、未交订单），输出 `*_CHECK_DONE` 即通过；
测试数据使用 `CHxx` 前缀并自清理。计划文档见 `docs/feature_plan.md`（D1–D14）与
`docs/phase2_plan.md`。
