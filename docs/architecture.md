# 架构与代码实现

> 更新于 2026-11-07（README 待优化事项批量交付后）。设计决策背景见 `docs/feature_plan.md`（D1–D14）。

## 当前状态与快速恢复

**最近交付**（自上而下为时间倒序，提交号可 `git show` 查看详情）：

| 主题 | 要点 | 提交 |
|---|---|---|
| 签发页三项修复 | ① **本次数量默认 0**（原默认填满可分配数，多行清空不便）：要签发的行手工填写，留空/0 不签发（控制器本就过滤 qty≤0）；② **型号/价格一致性拦截**：所选行 `generic_part_no` 或 `unit_price` 不一致直接报错（一张六联单=一个型号一个价；`add_line` 追加行同口径校验）；**坑**：`raise ActiveRecord::RecordInvalid, "msg"` 会把 msg 当 record 调 `.errors` → NoMethodError 500，须用普通字符串异常（`resolve_item` 同款隐患一并修复）；③ **流水号撞号修复（「Serial number已经被使用」根因）**：生成由 `当年 created_at count+1` 改为 `本年 XS 前缀下已有最大号+1`——六联单导入回溯 created_at 且文件自带流水号，count 远小于最大流水必然撞号；附带：**flash toast 在表单 422 重渲染后不显示**（布局 inline script 依赖 turbo:load，该路径不触发）→ application.js 加 `turbo:render` 监听统一显示；冒烟 `tmp/check_issue_fix.rb` | （本次提交） |
| README 待优化事项批量交付（6 项） | ① **可搜索下拉组件**（`searchable_select.js`：`select[data-searchable]` 上方注入过滤框，原生 select 表单值语义不变，占位项过滤时保留）+ 客户下拉改**中文名**（`cust_name`，按 name_zh,name 排序）——工作台快捷创建行、六联单快捷选客户行、价格快速创建行、月度对账客户下拉四处；② **月度对账（全部客户）**：订单核对/未交订单两段去「报价号」列，**单价即链接**跳报价详情（`InternalMonthlyStatement::Row` 增加 price_id；Excel 导出仍保留报价号）；三段单客户表格抽成 `statements/_statement_sections` 共享 partial；③ 价格列表**备注截断**（前两字+省略号，悬浮 title 全文，visually-hidden 锚点保列筛选）；④ **产品/客户列表快捷编辑对齐价格列表**（编辑 form 移表格外 + 输入 td 加 visually-hidden 锚点 + 编辑/取消链接带 query——根修「跳回顶部/编辑行被筛选过滤消失」）；⑤ **销售总览统一人民币口径**：金额度量时美元客户每月按当月汇率折¥（`split_matrix_by_currency(convert_usd:)`，缺汇率按 7 兜底；数量度量不折算）、段内排序=大类→当前度量全年值降序→客户名（视图层 sort_entries）、新增「全部客户合计」行（`admin/_grand_total` partial，三个 tab 共用）——人民币/美元/合计三表统一 `table-layout:fixed` + 相同 colgroup（大类 9%/客户 13%/月份均分/全年 8%），月份列逐列对齐（auto 布局下各表独立算宽必然错位）；⑥ **客户详情页精简重构**：当月对账三段（月份可切，默认当月）+ 已签发待发货（production_lines 存在 unshipped_qty>0，`sales_orders/_orders_table` remaining 渲染）+ 价格列表同列表页列格式（默认仅生效 `Price.available`，`all_prices=1` 显示全部非归档），移除商机与全量六联单列表；附带：`shipped_matrix` 孤儿出库行防御（sales_order 缺失跳过） | 00222d3 / 117c4ef / 2341fb0 / ca2a89b / f34b53d / 65230e1 / ce3befa |
| 订单价格参考价语义（D18 修订） | **Excel 单价为粗略参考价**：匹配键 = 客户+通用型号+接收日期在有效期内（**不再含单价一致性过滤**）；**订单行正式价格 = 匹配到的报价总价/成分**（价格表权威）；**差异守卫**：选中报价与 Excel 参考单价差 > 0.01 → 阻断该行（消息带订单号/报价号，参考价不吸收差异）；多候选收敛：同档并列选「与参考单价最接近」→ 生效最新；无候选仍阻断（无跨客户兜底）；**汇总校验移除金额合计**（参考价语义下 Excel 金额必然有口径差，校验无意义），行数/数量合计保留（核销覆盖/丢行防护不回退）；价格表 **5 位小数精度**（prices/order_lines 价格列 scale 2→5，导入解析/公式原值入库）；自洽校验容差回退宽松 0.005；验证脚本 `tmp/verify_import_strict.rb` / `tmp/verify_price_precision.rb` | e45c20c / 31064f3 / d9df1e1 / 50fa48d |
| 订单号防误拆修复 | **根因**（生产六联单分配大量「订单行不存在」）：客户订单 PO 尾数字被 `\A(.+)-(\d+)\z` 无条件剥离——德亿真实 PO `DYA421-20260113301` 落库成 `DYA421`+行1（长尾号丢失），六联单引用完整尾号即查不到（同案：PO-260703-061/YS-2026051001/MYT-2026-032801/ST-RP/CLPO-2608）；`A72329` 则是两行同型号未写行号 → 歧义误报「不存在」。**修复（最终规则，用户确认）**：行号写法 = **「# + 一位数字」**（PO123#1/#2 归并订单 PO123 行 1/2）；其余尾缀一律不合并、整串为订单号（-01/-02/-1/_2、长尾客户编号 DYA421-20260113301、订单序号 ACKPO-260325-02/PO-260703-061 等——彻底消除行号与订单序号的形式歧义），客户订单导入、六联单分配引用、UI 行号预显（PO123#N）三处同口径；错误消息细化区分「订单不存在」vs「多行歧义请用 订单号#行号 引用」。**附带修复**：`Item.parse_full_part_no` 注册表优先改为**不分类别**（此前仅 Baseband 档案生效，非 Baseband 命中档案后仍落入 SCT 10 位位置拆分——生产 order 473 的 RF 类 SCT9389HDK 被拆成 SCT9389HD+K；现命中档案即以档案通用型号为准）；导入 `parse_date` 支持 **Excel 日期序数**（5 位数字如 45757 → 2025-04-10）+ 六联单**重导刷新 created_at**（此前下单日期序数解析失败致 419 张全部落导入当月，排产核对按月归集错位）。**生产善后**：残留前缀单（DYA421/PO-260703/YS/ST-RP/MYT-2026/CLPO-2608/ACKPO-260325/SFE 等拆坏单）与误拆通用型号的订单行（SCT9389HDK→HD 类）须重导纠正；产品档案若为旧代码导入的拆分数据（generic+suffix 误拆）需重导产品表归一；**六联单需重导一次**（刷新 created_at 到下单日期） | f37c766 / 239b7de / 48c257f / a74e181 |
| 对账归档路线（核对工作流移除） | **方向调整**：专用核对工作流（指纹四表导出→编辑→上传预览→应用，3.1/3.2 交付后移除——主工作簿含公式/提示列，往返复制不实用）替换为**每月对账归档**：① 内部对账单加第四段「排产核对」（当月下发六联单 + 分配台账明细串接「订单行×数量」，可与 Excel FIFO 公式结果逐行对照；Σ分配≠数量 黄色高亮）；② 关账归档三件（pg_dump + 月度工作簿 + **当月对账单** cute_erp_statement_*.xlsx）；③ **区间汇总导出**（月度对账页 FROM/TO 选月，每月一个 sheet 纵向四段，限 24 个月）——每月关账留存一份核对过的 Excel 快照，即「系统之外核对过的数据」。imports 表 sha256/status 列保留（无害）。脚本 `tmp/verify_statement_archive.rb` | （待提交） |
| 导入预检强化（phase3 3.5） | **D18 客户订单严格价格匹配**：接收日期+客户+通用型号+含税单价须命中本客户报价（日期在有效期内），匹配不到→阻断（删跨客户兜底、删比例缩放），多候选→警告取生效最新；**核销只认数量为负**（标注不参与识别），价格继承原行快照；**D19 六联单分配严格一致**（相同客户/通用型号/价格，不一致阻断点名）；价格导入 **Price_number 同文件唯一**；验证脚本 `tmp/verify_import_strict.rb` | 0166156 |
| 导入检查标注增强 | 「检查」仅有警告（无错误）时也生成标注文件（横幅/下载名改中性「标注文件」）；价格导入：同客户+型号+档位已有未过期价**不再自动替代旧价**，仅警告人工复核（新价生效由 match_for 生效日期最新规则自然保证） | dea63d9 |
| 边界日期统计修复 | datetime 列（shipped_at/created_at）与 Date 区间（`all_month`/`fy_range`）比较时端点按 UTC 午夜 cast（北京时区即当日 08:00），漏掉 1 日 0~8 点与末日 8 点之后的单据——「普星 2026-04 四笔只统计两笔」即此因。修复 8 处：双对账单与月度工作簿 `@range`、`SalesPlanEntry.fy_range`、`RevenueQuery.monthly_rmb`、`SalesOverviewQuery` 月度区间、出库单列表月份筛选，统一改用 `beginning_of_day..end_of_day`。**新增查询一律勿用 Date 区间过滤 datetime 列** | 8d13d37 |
| 币别修复 + 体验优化 | USD 客户显示 RMB 修复：出货段币别兜底改客户现币别（internal/revenue/workbook/statement 四处 `|| "RMB"` 移除）、销售总览按**客户条目**判币别拆段（不再按大类整组）+ money 币别符号 + 分段合计行；核销单导入接收日期落库（`create_return_order` 补 created_at，重导刷新）；对账单按币别拆「人民币/美元客户」分节小计（页面+导出）、去币别/附加列、日期首列并按日期排序（CSS 覆盖 dt-type-date 右对齐）、客户下拉中文名、三段表接 datatable 筛选；列表筛选状态记忆（DataTables `stateSave` + 筛选框回填 + 价格编辑/批准/快速创建 redirect 带回 scope）——价格列表「筛选下编辑行消失」即此根因；销售总览 ③ 产品视图改为**客户订单视图**（`SalesOverviewQuery.order_matrix`：与实际出货同版式 数量/芯片额/软件额/总额，订单行直接计价含冲销负数，按客户币别分段）；**生产数据回填待执行**：`RAILS_ENV=production CONFIRM=1 bin/rails cute_erp:fix:order_currency`（先 dry-run 预览），历史订单币别按客户现值修正并按订单月重快照汇率 | （待提交） |
| 命名规则细化 | 完整型号解析**注册表优先**（命中产品档案→用档案通用型号/后缀）；命名校验**仅产品类别 = Baseband**（RF 等其他类别通用型号 = 完整型号）；**长度不限制**（通用型号有 7 位 SCT1234 与 9 位 SCT1234XY 两种形态） | 63cd80b / 2ad9d3a / e18da14 |
| 产品导入归一 | 产品导入/新建：**通用型号 = 型号原文**（不再拆末位字母）；重导同型号自动归一老拆分数据（SCT3288T+D → SCT3288TD） | 9626574 |
| 接收日期/下单日期落库 | 客户订单/六联单导入把文件日期写入 created_at（列表/关账按此口径）；**重新导入以文件日期刷新**；客户订单列表标题改「接收日期」 | 11674dc / cca1273 |
| 版本可选 | 客户订单导入版本不再必填 | c6349ca |
| 型号命名规则（按位） | 9 位=通用/10 位=通用+后缀（第 10 位 ∈ C/M/S，见「型号命名规则」）；订单导入严格校验；`order_lines.full_part_no` 落客户所订原文、`production_lines.suffix` 落转产后缀 | 745c784 / fe7dfc2 / a4ed31a |
| 两阶段导入 | 预检干跑（事务回滚）→ 错误标注文件 → 修正后导入；六类导入全覆盖（客户订单/价格/六联单/出库单/客户/产品），均有「检查」按钮 | c68284a / 8367ab3 / 407e85c |
| 价格导入规则 | 芯片必填、声码可缺省；成分合计≠总价直接报错（按显示值 2 位小数取值）；同客户+型号+档位新价自动替代旧价；**状态空白/无法识别 → approved**（requested 显式保留待审批） | 1d8f00c / fcf5840 / 4d83cb2 / c5df1d1 |
| 报价单重构 | QT 号 + 快照明细（价格可复用不随调价漂移）；PDF 输出 | cf178fa |
| 出库单导入 | source_key 幂等；分组合单；列表月份筛选 | c8e082b |
| 导入中心 | 六卡片（含客户/产品导入）；月份选择已移除（日期在文件内）；批次含错误/警告明细 | 319bf5f |
| 列表体验 | 日期列月份下拉、数值列 `最小~最大` 区间语法、表格紧凑（行高统一）；六联单列表分页/信息显示 | 456b8be / f8dd31c |

**待办 / 注意**：

- **生产库订单币别回填（待执行）**：历史订单币别是建单时快照，客户改币别后旧单不跟随。
  先 dry-run 预览：`bin/rails cute_erp:fix:order_currency RAILS_ENV=production`，
  确认后 `RAILS_ENV=production CONFIRM=1 bin/rails cute_erp:fix:order_currency`
  （update_columns 绕过关账守卫；汇率按订单月重快照，缺失月份先在汇率页补录）
- 生产测试环境（3001）部署固定流程：`bin/rails db:migrate RAILS_ENV=production` →
  `yarn build && yarn build:css && bin/rails assets:precompile RAILS_ENV=production` → 重启
- **生产库产品数据归一（待执行）**：生产库产品由旧代码导入，通用型号被误拆
  （如 SCT3288TD 存成 generic SCT3288T + suffix D）。部署后在导入中心**重新导入一次产品表**
  即自动归一（通用型号 = 型号原文、后缀清空），之后客户订单导入的型号校验才能通过
- 生产库（5433/cute_erp_production）与开发库数据独立：客户/产品先行，订单链路随后
- 前端改动上线三件套：`yarn build`（JS）、`yarn build:css`（CSS）、`assets:precompile`（指纹清单），
  缺一生产端不生效

## 技术栈

| 层 | 选型 | 说明 |
|---|---|---|
| 框架 | Rails 8.1（Ruby 3.3） | 传统服务端渲染单栈（无前后端分离） |
| 数据库 | PostgreSQL 16 | 唯一持久层；无缓存队列等附加服务 |
| 前端 | Propshaft + esbuild + Bootstrap 5 + jQuery + DataTables 3 | Turbo 轻量使用；交互多为传统表单 + 局部脚本 |
| Excel | roo（读）/ caxlsx（写） | 月度工作簿导出与导入共用一套模板 |
| PDF | wicked_pdf（wkhtmltopdf） | 报价单 / 价格单 / invoice / packing list |
| 附件 | Active Storage（本地磁盘） | 客户订单 PO 附件（PDF/图片），可多文件 |

## 代码结构（关键目录）

```
app/
├── models/            # ActiveRecord 模型 + concerns（ClosedPeriodGuard/DocumentAttachment）
│                      #   Price（match_for 价格匹配 / split_amount 成分缩放）
│                      #   OrderLine（台账聚合：allocated/delivered/open_qty）
├── queries/           # 读模型/查询对象：DemandQuery、RevenueQuery、SalesOverviewQuery、
│                      #   MonthlyStatement（客户对账）、InternalMonthlyStatement（全客户内部对账）
├── services/          # MonthlyWorkbook（月度工作簿导出）、Xlsx（极简 xlsx 生成器）、
│                      #   CustomerOrdersImport / SalesOrdersImport / ShipmentsImport（+ Price.import）、
│                      #   ImportChecker（两阶段导入预检）、BackupService（归档三件含对账单）
├── controllers/       # 按业务域划分；imports 为导入中心（含预检与标注文件下载）
├── javascript/lib/    # column_filters.js —— DataTables Excel 式列筛选框架
│                      # searchable_select.js —— select[data-searchable] 可搜索下拉（零依赖）
└── views/
    ├── layouts/pdf.pdf.erb   # 自包含打印样式（内嵌 CSS，见「PDF 渲染」）
    └── 共享局部模板（orders/_lines_table、sales_orders/_orders_table）
db/migrate/            # 迁移即 schema 历史；active_storage_* 为附件表
```

## 数据模型（业务表）

```
customers ──┬── prices ──┐                    # 报价：客户×通用型号×档位，成分三列+币别+生效期
items ──────┘            │                    # 产品：通用型号+后缀=完整型号；extra_item=声码组件
                         ▼
orders ── order_lines ───┘                   # 客户订单：po_number 唯一；行=po+line_no 唯一
  │        │          （kind: normal/return，status: draft/submitted）
  │        ├── refer_order_line_id            # 冲销行（数量为负）引用原行（D1）；余额校验按总额口径
  │        ├── full_part_no                   # 客户所订完整型号原文；generic_part_no 由命名规则派生
  │        ├── base/v1/v2_price + price_id    # 价格快照（下单/导入时点，可追溯报价来源）
  │        └── documents                      # Active Storage 附件（客户 PO PDF，多个）
  │
  └── production_allocations ──► production_lines ──► sales_orders
       分配台账（D2）              六联单行              # serial_number 唯一；status: draft/submitted
       （跨订单拆量）              （item=通用型号产品；suffix=转产定型后缀）
                                        │
                                        └── shipment_lines ──► shipments
                                             出库明细           # source_key = 六联单号|日期|快递号
                                                               # （导入幂等键，整单重建）

quotations ── quotation_lines                # 报价单：QT号；明细=价格快照（可复用同一价格，不随调价漂移）
exchange_rates                              # 按月汇率（多币种折算，D9）
sales_plan_entries                          # 年度销售计划（FY 止年，D12 前置）
imports                                     # 导入批次（stats 含 created/updated/skipped/errors/warnings）
closed_periods                              # 关账月（ClosedPeriodGuard 拦截期改期删）
```

## 导入体系（两阶段：预检 → 修正 → 导入）

六个导入器统一走 `ImportsController`（导入中心）与月度工作簿同模板，均**按表头名称解析**
（容忍列序变化/空列/多余统计列）：

| 导入器 | 模板表 | 自然键 | 特性 |
|---|---|---|---|
| `CustomerOrdersImport` | 客户订单 | 订单号+通用型号+版本 | 型号命名规则仅 Baseband：SCT+4位数字+XY[+Z]，9位=通用/10位=通用+后缀，位次或后缀非法报错，通用型号未建档报错；**严格价格匹配（D18）**：接收日期+客户+通用型号+含税单价须命中报价（日期在有效期内），匹配不到→阻断（无跨客户兜底、无比例缩放），多候选→警告取生效最新；**冲销只认数量为负**（标注不参与识别）→ 冲销单「PO-Rn」，价格继承原行；**多笔核销并存（核销单序）**：核销行订单号写 原PO#序号（PO#1/-20、PO#2/-30 → 两张独立核销单 PO-R1/PO-R2，各自接收日期互不覆盖；同 # 重导幂等更新；不写 # 视为单笔核销覆盖更新，兼容存量）；**PO 解析（最终规则）**：仅「# + 一位数字」尾缀视为 行号 写法（PO123#1/#2 归并），其余一律不合并整串为订单号（-01/-02/-1/_2、长尾客户编号、订单序号等）；UI 行号预显同格式（PO123#N） |
| `Price.import` | 价格 | Price_number（**同文件唯一**，重复报错） | 必填校验（芯片必填，声码可缺省）；成分合计≠总价直接报错（按显示值 2 位小数取值）；同客户+型号+档位已有未过期价**不自动替代**，仅警告（旧价失效人工处理） |
| `SalesOrdersImport` | 生产订单-六联单 | 六联单号 | 导入即 submitted（D14）；分配对「订单N」支持纯订单号；「产品」列完整型号→suffix 落行；分配直接建台账；**分配目标与六联单行严格一致（相同客户/通用型号/价格，D19）** |
| `ShipmentsImport` | 出库单 | source_key（六联单号\|日期\|快递号） | 同键多行合单、同产品累加；重复导入整单重建（幂等） |
| `Customer.import` | 客户 | 英文名（中文名唯一） | 客户订单导入的前置；资料更新幂等 |
| `Item.import` | 产品 | 通用型号（同文件唯一） | 订单导入的前置；建档后六联单可引用 |

**两阶段流程**（`ImportChecker`）：

1. **预检（干跑）**：在回滚事务中完整执行导入器，**不落任何数据**；
   结果分 `errors`（阻断：客户缺失/型号未建档或命名规则不符/引用不存在/分配超余额/Σ分配≠数量/
   订单无匹配报价/分配与六联单不一致/价格文件报价号重复等）
   与 `warnings`（不阻断：同档位多条同价候选/同档位已有未过期价等），均带行号
2. **「检查」按钮**：只跑预检（有错误**或警告**均生成标注文件）；「导入」按钮：先预检，有错误即**阻止导入**
3. **标注文件**：预检发现错误或警告时生成 xlsx（原表 + 末列「检查结果」逐行标注错误/警告，
   另有「全局问题」表），存 `tmp/import_checks/`（30 分钟），导入中心顶部横幅提供下载
   （token 存 session，跨刷新持续显示）；修正/复核后重新上传导入

### 预检内容

errors（阻断导入）均带行号写回标注文件；各导入器的具体规则：

| 导入器 | 阻断性检查（errors） | 非阻断提示（warnings） |
|---|---|---|
| 客户 | 英文名必填；公司全称/销售类型/币别必填；中文名唯一（与库内其他客户及同文件行均不冲突） | — |
| 产品 | 型号必填且同文件唯一；产品名称/描述/类别必填 | — |
| 价格 | Price_number/客户/通用型号/总单价/订单量/芯片必填（声码1/声码2 可缺省，缺省并入芯片；总单价为 =公式 时芯片豁免）；**Price_number 同文件唯一（重复报错）**；客户必须已建档；成分合计≠总价直接报错（按显示值 2 位小数取值）；同客户+型号+档位已有未过期价仅警告**不替代** | — |
| 客户订单 | 订单号/型号/接收日期/数量/含税单价必填（核销行免含税单价；版本可选）；型号命名规则校验（见「型号命名规则」）；客户与派生通用型号必须已建档；**严格价格匹配（D18）：接收日期+客户+通用型号+含税单价须命中本客户报价（日期在有效期内），匹配不到→阻断**；核销（只认数量为负）：原订单存在且余额足够（价格继承原行） | 同档位多条同价候选（取生效日期最新） |
| 六联单 | 客户/产品已建档；数量 ≥ 已出库；分配引用存在且不超余额；Σ分配 = 数量；**分配目标与六联单行严格一致：相同客户/相同通用型号/相同价格（D19，含税单价列填了才比价格）** | — |
| 出库单 | 六联单号/产品/数量必填；六联单与产品行必须已建档且可匹配；数量 ≤ 未出库 | 客户与六联单不符（按六联单客户处理） |

> 客户/产品为订单链路的前置，建议先「检查」通过再导订单。

### 型号命名规则（Baseband，位置固定）

```
完整型号 = SCT + 4位数字 + XY + [Z]
           └─ 前 9 位 = 通用型号 ─┘  └ 第 10 位 = 后缀（可缺省）
```

- **按长度派生**：9 位 = 通用型号（后缀缺省，如 SCT3089MM 就是通用型号）；
  10 位 = 通用 + 1 位后缀（如 SCT3089DVC → 通用 SCT3089DV + 后缀 C）
- 后缀集合在用户设置 `naming.suffixes` 维护（默认 C/M/S），签发后缀下拉与导入校验共用
- 订单导入校验：**仅产品档案类别 = Baseband 的型号**检查第 10 位后缀合法性（∈ 设置
  naming.suffixes）；长度不限制（通用型号有 7 位 SCT1234 与 9 位 SCT1234XY 两种形态）；
  派生通用型号未建档 → 报错
- 产品列表只维护通用型号（产品导入按同一规则派生存储）；Baseband 之外的类别
  （RF 等）通用型号 = 完整型号，不参与命名校验


## 价格匹配与成分拆分

**UI 快照**走 `Price.match_for`（客户 + 通用型号，含跨客户兜底与比例缩放），逐级收敛：

```
客户 + 通用型号 → 已批准(approved/active) → 币别一致
→ 有效期以「接收日期」为基准（as-of，支持补录历史）
→ 数量档位：订单量 ≤ 数量的最高档；低于最小档取最低档（MOQ）
→ 并列取生效日期最新；本客户无价时退同型号其他客户报价（标记警告）
```

成分拆分（`OrderLine.apply_price_snapshot` / `Price.split_amount`）：

- 订单含税单价 ≈ 报价总价（容差 0.01）→ 直接快照三成分
- 不一致（砍价/调价）→ 按 报价成分**比例缩放** 到订单实际单价，尾差并入芯片，
  保证三成分之和恰等于订单单价；报告警告供人工复核
- 匹配成功写 `order_lines.price_id`，台账可追溯；同一价格可进多张订单/报价单

**订单导入走正式价格匹配**（`CustomerOrdersImport.match_formal_price`，参考价语义）：
客户+型号+接收日期在有效期内命中本客户报价（**Excel 单价为参考价，不参与匹配键**）；
**订单行正式价格 = 匹配报价的总价/成分**（价格表权威）；有参考单价时选「报价与参考单价最接近」
的档位，并列取生效最新；**差异守卫：选中报价与参考单价差 > 0.01 → 阻断该行**（参考价只定位
报价不吸收差异）；匹配不到仍阻断（无跨客户兜底）

## 报表与导出

- **月度工作簿**（`MonthlyWorkbook`，`GET /exports/monthly`）：7 张表
  （汇总/计划/出库单/价格/客户/产品/未交订单），出库单成分列与导入模板同口径
- **客户对账单**（`MonthlyStatement`，`/statements`）：客户 × 月份三段式
  （订单核对/出货核对/未交订单），含冲销行（负金额），页面 + 单客户 xlsx 导出
- **全客户内部对账单**（`InternalMonthlyStatement`）：
  **四段式**：订单核对 / 出货核对 / 未交订单 + **排产核对**（当月下发六联单 + 分配台账明细
  「订单行×数量」串接、Σ分配/已发货，Σ分配≠数量 黄色高亮——可与 Excel 六联单表
  FIFO 分配公式结果逐行对照），跨全部客户合成，排序 币别 → 客户名称 → 日期 → 单据号；
  页面按客户币别拆「人民币客户 / 美元客户(USD)」分节显示（`datatable` 筛选 + 分节小计），
  导出按币别小计 + 段合计折 RMB；金额按 芯片/声码1/声码2 成分拆分列示
  （出货段用分配加权价，与月度工作簿同公式；**出货币别 = 分配订单快照币别优先、客户现币别兜底**）；
  汇率随行，段合计折 RMB
- **区间汇总导出**（`GET /statements/export_summary?from=&to=`）：每月一个 sheet（纵向四段：
  订单核对/出货核对/未交订单/排产核对，各段含标题/表头/合计），合成一个工作簿；限 24 个月
- **关账归档**：`BackupService.archive_month` 归档三件——pg_dump + 当月工作簿 +
  **当月内部对账单**（`cute_erp_statement_*.xlsx`，`statement_xlsx` 生成，与导出同口径）——
  关账即留存一份核对过的月度数据快照（系统之外核对过的 Excel 数据）
- 统一出口 `Xlsx.generate`（caxlsx）；金额未税一律 含税 ÷ 1.13

## 核心口径（全系统统一）

| 口径 | 公式 | 实现位置 |
|---|---|---|
| 净需求 | 订单量 − 冲销 − 已分配 | `DemandQuery`（签发池/工作台） |
| 可分配余额 | 净需求 − 已分配 | `OrderLine#allocatable_qty` |
| 已出货（订单行，对账） | 分配比例 × 生产行出库 之和 | `OrderLine#delivered_qty` |
| 未交订单 | 数量 − 冲销 − 已出货 | `OrderLine#open_qty`、对账单 Backlog |
| 营业额（折 RMB） | 出库数量 × 台账加权单价 × 当月汇率 | `RevenueQuery` |
| 生效价格 | approved/active 且在生效期内 | `Price.available / #effective? / #match_for` |
| 未税金额 | 含税 ÷ 1.13 | `MonthlyWorkbook::TAX_FACTOR` |

## 关键设计决策（详见 docs/feature_plan.md D1–D14）

- **D1 冲销 = 单据类型**：`orders.kind = return`，负数量行引用原行；
  余额校验按「全部冲销行合计 ≤ 原行数量」口径（自身除外）——支持导入幂等重导
- **D2 分配台账**：六联单行与客户订单行多对多（production_allocations），
  需求/余额全部由台账聚合派生；分配引用兼容 订单号-行号 与 纯订单号（唯一行自动对应）
- **D3 三成分固定列**：价格与订单行均为 base/v1/v2 三列（芯片/声码1/声码2）
- **D4 型号 = 通用型号 + 后缀**：转产时六联单行确定后缀
- **D9 多币种**：币别在客户上；订单/六联单创建时快照当月汇率；报表按出货月折算
- **D12 关账同包**；**D13 不做单月回灌**（恢复=整库归档点）；**D14 过渡期 Excel 为准**
  ——导入即权威：六联单直接 submitted、出库整单按文件重建
- **报价单 = 快照明细**（quotation_lines）：生成时复制价格成分，price_id 仅追溯；
  报价号 QT+日期+3位流水（删除安全），与价格 QO 号同规则
- **两阶段导入**：预检干跑（事务回滚）→ 错误标注文件 → 修正后导入；
  导入永不带错落库
- **状态机**：六联单 草稿（不占池）→ 提交（占池、可出库）→ 已出完（列表隐藏出库入口）；
  客户订单 草稿 → 提交（ODM 须最终客户）→ 未签发可随意改 → 签发后走冲销

## 前端（列表页统一模式）

- 每表：标题行 + **筛选行**（`column_filters.js` 注入）+ tfoot **快速创建行**
- 列筛选按列型自动选择：
  - 日期列 → **月份下拉**（`(全部月份)`，选项从数据提取，Excel 风格；
    如需 从/到 区间显式 `data-filter="daterange"`）
  - 数值列 → 单输入框区间语法：`100~500` 区间 / `~500` ≤ / `100~` ≥ / `100` 精确
  - 枚举列（≤10 个不同值）→ 下拉精确匹配；其余 → 文本包含
  - 筛选行在创建表单内：回车被拦截，避免误触发创建
- 表格紧凑约定：`table-sm` + DataTables 单元格 `white-space: nowrap`（宽表横向滚动）+
  表内 `.btn-link` 无垂直内边距 —— 各列表行高统一 ~33px
- **筛选状态记忆**：DataTables `stateSave`（localStorage，8 小时）持久化排序/分页/字符串类列筛选，
  整页跳转（如价格行内编辑）回到列表后自动恢复原筛选/页码——被编辑行不再「消失」；
  筛选输入框显示值由 `column_filters.js` 从列搜索状态回填（数值/日期区间筛选无法序列化，不恢复）；
  价格列表的服务端 scope（status/is_prr）经表单隐藏字段 `list_*` 随 redirect 带回
- 报价号/单号联动：订单页 `next_line_no` 接口返回 PO 是否存在与下一行号
- flash 用右下角 toast（通知自动消失，错误常驻）；下载链接一律 `data: { turbo: false }`

## PDF 渲染（通用方案）

wkhtmltopdf 引擎为 Qt WebKit（无 flexbox），且生产环境代码冻结——因此
**自包含打印样式直接内嵌于 `layouts/pdf.pdf.erb`**：

- 映射模板中已使用的类名（card/table/text-end/row-col 用 float 模拟）；`.btn` 打印隐藏
- 中文靠系统字体栈（Droid Sans Fallback 优先），不依赖资产管线，改布局即全量生效
- 所有 PDF（报价单/价格单/invoice/packing list）共用；新增模板用这些类名即有格式

## 环境与部署

| 环境 | 端口 | 特性 |
|---|---|---|
| 开发 | 3000 | 代码热加载（ERB/RB 即改即生效）；JS/CSS 需 `yarn build` / `yarn build:css` |
| 生产测试 | 3001 | 代码冻结：改后必须重启；资产需 `bin/rails assets:precompile RAILS_ENV=production`
（生产引用 `public/assets` 带指纹副本）；有迁移先 `db:migrate` |

- 前端上线固定动作：`yarn build && yarn build:css && bin/rails assets:precompile RAILS_ENV=production` + 重启
- 数据库密码仅在 `config/credentials/production.yml.enc`（key 不进 git）；
  `storage/`（附件）与 `tmp/import_checks/`（标注文件）不进 git
- 群晖 NAS 部署见 `docs/deploy_synology.md`（Container Manager + docker-compose）

## 测试与验证

- 无固定测试套件；验证方式为 `bin/rails runner tmp/verify_*.rb` 场景脚本
  （构造数据 → 断言 → 自清理），以及浏览器真机操作验证（列表筛选、导入流程、PDF 外观）
- 关键回归点：价格匹配档位/缩放、冲销余额、台账聚合、两阶段导入阻断与标注、
  出库幂等重建、对账单口径
- 计划文档：`docs/feature_plan.md`（D1–D14）、`docs/phase2_plan.md`、`docs/phase3_plan.md`
