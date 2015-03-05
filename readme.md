## rorWebERP(cuteERP) introduce

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
- delete opportunity 应该同时删除，相应的oppostatus
- customer order fix
- best in place opportunities status can't save(pg or bootstrap?)

#### feature bug fix
- oppostatus default current user.
- status mark default uses last status
- todo status using auto; with label color

### Feature request
- Price, customer price,
- Products, create chipset
- auto make quotation(pdf)
- add Markdown notes in customer show page
- Docs, fetch 1st line as post title
- Docs, add edit preview in the same page.
- Orders index with lineitems(like excel)
- Packing Note
- Opportunities priority style : 1-2, 1-3, 2-2 客户排名；项目排名；
- Opportunities solution: DT(SCT3258); WT(SCT3258)
- Items and Customers show: add wiki content
- customer/show: add new opportunity modal
- English/Chinese switch(Product name, currency $, RMB),customer payment type
- Opportunities: prority强制转换中英文字符和格式编码；
