## rorWebERP introduce

超小型的ERP系统， 参考WebERP。

界面更简单

#### tips
- DEMO on heroku demo地址
- 默认用户名 admin； 密码：rorWebERP

#### 实现步骤
##### 1.参考Rails in Action实现一个简单，简洁，但可靠的ERP。
 - Overview界面涉及绝大部分功能，
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


#### database table
- Customer:
- Opportunity: belongs_to: customer, :priority, :project_type, :design, :description
- Status: belongs_to: opportunity, :status, :issue, :label
- Task: :destription, :assign, :status(Doing,Done,Fail,Forgive) 
