## rorWebERP introduce

超小型的ERP系统， 参考WebERP。

界面更简单

#### tips
- DEMO on heroku demo地址
- 默认用户名 admin； 密码：rorWebERP

#### 实现步骤
##### 1.参考Rails in Action实现一个简单，简洁，但可靠的ERP。
 - Overview界面涉及绝大部分功能。
 - 根据User不同的权限和职能显示不同内容。如前台看不到客户交易，但可以看到快递单号。

##### 2.Moden UI： Ajax改造，表单的录入等。
 - JQuery UI？ JQuery ajax form.
 - Bootstrap？

##### 3.可编辑文档系统： 整合Markdown文件，替代Wiki。
 - 全公司都可以使用的文档系统，用于协调。

 tips:
 - Customer 中包含多个联系人
 - Opertunite： Product ID;
 - task

##### 4.添加部分CRM功能：oppotunite，task，自动生成客户项目等界面。
 - 在Sales overview汇总所有客户。

#### schema
- Customer:
- Opportunity: belongs_to: customer, :priority, :project_type, :design, :description
- Status: belongs_to: opportunity, :status, :issue, :label
- Task: :destription, :assign, :status(Doing,Done,Fail,Forgive)

- Product: name, part_number, price(lowest for key customer), price2(lowest for important), price3(lowest for normal), price4(marketing reference)
- Price: customer_id, product_id, value, unit,
- customer_order
- sales_order
- invoice

#### bug fix
- contacts 修改公司名不起作用 ok
- Opportunity 更改链接不直观
- opportunity edit中 customer默认错误，是否不能修改更合适（即必须由customer页面创建，然后不能修改）？ ok
- customer show中 Oppostatus 责任人不能修改 ok
- create at 时间格式不对
- customers 客户名应该加入链接，new customer名称也同样可以加 fail
- delete opportunity 应该同时删除，相应的oppostatus
- todo status应该能标注不同颜色，红，灰，绿
- 性能问题，是否render性能不好？
- best_in_place delete 编辑太方便，考虑锁的机制
- customer中加入备注text区域很需要 -> wiki貌似已经可以完全替代
-


### Feature request
- Price, customer price,
- Products, create chipset
- auto make quotation(pdf)
- add Markdown notes in customer show page
- Auto create Marketings, solutions page according to oppotunities  
- Docs, fetch 1st line as post title
- Docs, add edit preview in the same page.
- Orders index with lineitems(like excel)
- Packing Note
