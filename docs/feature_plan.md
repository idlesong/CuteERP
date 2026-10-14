# CuteERP 功能升级计划（Feature Plan）

> 版本：v1（2026-10-14 评审通过）
> 前置：Rails 8.1 迁移已完成（见 `upgrade_plan.md`）
> 总原则：大胆重构 · 业务逻辑优先 · 简洁 · 业界最佳实践
> 测试策略：每个工作包自带模型/集成测试（替代迁移期"测试先放弃"的约定）

## 0. 已定决策

| #  | 决策 |
|----|------|
| D1 | 冲销做成单据类型（`orders.kind = normal / return`），不再用负数行 |
| D2 | 跨订单签发用分配台账（`production_allocations`） |
| D3 | 价格成分固定三列：`base_price / v1_price / v2_price`，总额 = 三者之和 |
| D4 | 型号存储：items 去掉 `partNo` 列，改为 `generic_part_no`（前缀，如 TC2008AB）+ `suffix`（后缀字母 C/M/S…，可空）；完整型号 = 前缀+后缀，为派生值；后缀不做硬白名单，UI 下拉取库内已有值自动生长。**软件类别已编码于 generic_part_no 尾字母，不建 software_options/变体表**；生产时软件版本手动录入，软硬件价值拆分由 D3 价格成分承载 |
| D5 | 阶梯价：发布批次（releases）+ 阶梯行（entries）；最新批次可增补行；页面默认展示最新批次，历史批次只读可切换；不做跨批次矩阵页；定期 Excel 整表导入 = 新建批次 |
| D6 | 订单行 `version` 固化版本；`remark` 全局只表特殊要求 |
| D7 | 报价、客户订单按**通用型号**（generic_part_no）下单；生产订单时才确定完整型号（=选后缀）与最终客户 |
| D8 | 价格增加 `effective_from`（默认空 = 不生效）与 `expired_at`；可用价 = 审批通过 且 在有效期内 |
| D9 | 多币种：本币计价 + 单据快照汇率 + 营业额按报表当月汇率折算 RMB；汇率表按月手工维护 |
| D10 | 草稿态替代 session 购物车；订单行编辑用"筛选框 + 批量加行"交互 |
| D11 | 通用型号不建独立表，作为 items 上的字符串维度；报价/订单行/阶梯表均以该维度取数 |

## 1. P1 主数据

**items**
- 移除 `partNo` 列，新增：`generic_part_no`(string, 索引, 可重复)、`suffix`(string, 可空)
- 派生：`part_no = generic_part_no + suffix`；`generic_display = generic_part_no + "*"`
- 唯一性：`(generic_part_no, suffix)` 组合唯一
- 新增：`name_zh`、`extra_item2`、`eol_at`(停产日)
- 存量迁移：按"末位字母 = 后缀"自动拆分现有多 partNo，输出拆分清单人工复核

**customers**
- 新增：`name_zh`、`invoice_address`、`invoice_contact`、`invoice_phone`（发票三件套）
- `disty_id` 关系梳理（代理商→最终用户层级，P3 深化）

**exchange_rates（新表，多币种基础）**
- `month`(当月首日) + `currency`("USD") + `rate`，(month, currency) 唯一
- 设置页按月手工录入；迁移现有 User settings 中的汇率值；settings 汇率键废弃

## 2. P2 价格域重构

**prices 重构**
- 维度改为 `generic_part_no`（报价按通用型号）
- 成分三列：`base_price / v1_price / v2_price`，`price` 列保留为总额（= 三者之和，校验）
- 新增 `effective_from`（默认空=不生效）、`expired_at`；可用价判定 = status(approved/active) 且 在有效期内
- 新增 `currency`（建价时从客户快照，默认 RMB）
- USD 建价换算助手：`USD = RMB基准价 / 1.13 / 当月汇率`，自动填充、可改（换算只发生在建价一次）

**阶梯价重设计（替代 set_prices step1..16）**
- `price_list_releases`：`released_at`、`note`
- `price_list_entries`：`release_id`、`generic_part_no`、`sell_by`(OEM/ODM)、`min_qty`、`price`、`amended_at`
- 导入：定期 Excel 整表导入 = 新建批次（不覆盖历史）
- 页面：默认最新批次完整阶梯表（行=通用型号，列=OEM/ODM × 8 档）；批次下拉切换历史（只读）；最新批次可**增补行**（记录 amended_at）
- 保留 RMB 内部基准价定位；美元价从基准价派生（建价助手）

## 3. P3 客户订单重构

**order_lines（新行表，替代多态 line_items 的 Order 侧）**
- `order_id`、`generic_part_no`、`quantity`、`version`（固化版本）、`required_delivery_date`（要求交期，行级）
- 价格快照：`base_price / v1_price / v2_price`（下单时从价格带出，本币）
- `remark` 只表特殊要求

**orders**
- 新增 `kind`（normal / return，冲销单据，D1）
- 新增 `currency`（从客户快照）、`exchange_rate`（创建时快照当月汇率，RMB 单 = 1）
- 新增 `status`（draft / submitted，草稿态 D10）
- `end_customer_id` 已有；ODM 客户提交时必填，默认带出

**交互（D10）**
- 新建订单 = 创建 draft；行编辑区三段式：筛选条（通用型号前缀/group/family/关键词）→ 候选网格（带最新阶梯价参考 + 数量输入）→ 批量加入；已选行网格可改/删
- 冲销单流程：选原订单行 → 录冲销数量（≤ 可冲销余额）→ 自动对冲
- 废弃：carts 表、current_cart/current_issue_cart 及相关控制器分支

## 4. P4 生产履约重构

**production_lines（六联单行，替代 line_items 的 SalesOrder 侧）**
- `sales_order_id`、`item_id`（正式型号，转产时从同 generic 组选定 = 确定后缀；组内不存在时可就地新建）
- `quantity`、`version`（生产版本）、`full_name`（统一编号）、`remark`
- `end_customer_id` 在生产订单确认（默认带出，可改）

**sales_orders（六联单单头）调整**
- `serial_number` 规则改为：`XS{yyyy}-{年内流水}`（如 XS2026-192、XS2026-193，流水按年重置）
- `delivery_plan` 正名为 `required_date`（客户要求交期，来自客户订单行，与年度销售计划无关，见 P5）

**production_allocations（分配台账，D2）**
- `production_line_id` + `order_line_id` + `quantity`
- 跨多个客户订单、部分/全量数量，无张数上限，事后可调整
- 签发交互：客户维度"未签发 PO 行池"多选页 → 按行拆数量
- 存量迁移：`refer_line_id / quantity_issued` 一次性回填为台账记录，旧字段只读一版后废弃

**orders.kind = return（冲销，D1）**
- 冲销行引用原 `order_line`，数量 ≤ 已签发未发货余额
- 净需求 `DemandQuery`：Σ正常单 − Σ冲销 − Σ已分配；仪表盘/列表统一取数（"净化需求"）

**shipments / shipment_lines（出库单，想法 4）**
- `shipments`：`sales_order_id`、`shipped_at`、`tracking_no`(快递号，仅存储)、`note`
- `shipment_lines`：`shipment_id`、`production_line_id`、`quantity`
- 可多次发货；发货列表按 `shipped_at` 排序；`sales_orders.delivery_date` 变为派生（末次发货）

**多币种报表**
- `RevenueQuery`：营业额(月) = Σ( quantity × fixed_price × 当月汇率 )；汇率取 exchange_rates 表报表当月值
- admin 仪表盘、销售/产品滚动预测改走该查询对象（美元/人民币单统一折算）

## 5. P5 仪表盘与年度销售计划（独立包，可先于 P1–P4 实施）

**sales_plan_entries（年度销售计划，对齐 Plan.xlsx 版式）**
- `fy`（按止年标记：**FY2027 = 2026-04 ~ 2027-03**）、`customer_id`、`product_group`（= items.group，大类）、`month`（财年各月首日，四月~次年三月）
- 度量：`quantity`、`chip_amount`（硬件，对应 base_price 口径）、`software_amount`（软件，对应 v1_price + v2_price 口径）；总额 = chip + software（派生）
- 唯一 `(fy, customer_id, product_group, month)`
- 币别不单设维度：按 customer.currency 派生人民币/美元分节，汇总均折 RMB

**导入（roo 解析 Plan.xlsx 版式）**
- 结构：货币段（人民币/美元）→ 产品大类 → 客户行（美元段后续补充逐客户明细，导入器按客户行统一处理）；各级合计行不导入（系统自动聚合）
- 客户名匹配 name / full_name / name_zh，失败进校验报告；大类与 items.group 值匹配校验

**仪表盘重排（三视图 + KPI 移除）**
- ① 实际出货：大类 → 可展开客户；行尾并入 全年Plan / 当月Plan 对比
- ② Plan (Budget)：货币段 → 大类 → 客户；数量 / chip / 软件 / 总额切换
- ③ 产品视图：product_family 实际出货
- 口径修正（Q4）：`delivery_plan` = 客户要求交期，与 Plan 无关；Plan 为本包独立录入的年度计划
- 实际值取数：`SalesOverviewQuery` 读模型（现读旧表，P4 后切换 production_lines/shipments 取数源，签名不变）

## 6. 交付顺序与依赖

```
P1 主数据 → P2 价格域 → P3 客户订单 → P4 生产履约
P5 独立于四者（纯增量，读模型屏蔽后续取数源切换），建议最先实施
```
- 价格按通用型号（P2）依赖 P1；订单行按通用型号+成分快照（P3）依赖 P2；台账/冲销/发货（P4）依赖 P3 的 order_lines
- 每包交付含：数据迁移（含存量搬运）+ 模型/逻辑 + UI + 测试 + Excel 导入兼容
- Excel 导出在 P4 后统一升级为按月工作簿导出（见第二阶段计划）

## 7. 第二阶段（已立项）

- 按月对账（订单核对/出货核对：金额、数量）+ 月度关账
- 按月备份与恢复（关账触发归档）
- Excel 并行：按月导出工作簿 + 生产订单（含 FIFO 分配结果）导入
- 详见 `phase2_plan.md`（D12–D14 已定）
