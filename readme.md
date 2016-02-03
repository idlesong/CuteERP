# rorWebERP(cuteERP)

A cute online ERP, with order system, docs system.

## Features
## customers
1. customer: name(nick name), full_name, has_many contacts, has_many deliver_info(address,contact), balance, payment_term
1. contacts
1. delivery_info: contact, address, email, telephone, customer_id, default
1. wiki

## products
1. products
1. wiki

## order system
1. customer order: customer_id, has_many line_items, received_date, total_amount, request_date, po_number, attachment(pdf po)
1. sales order: order_number, customer_id, line_items(with po number), total_amount, delivery_info_id,
1. price: price, customer_id, item_id
1. invoice
1. packing list


## payment & receivable
1. payment
1. receivable account
1. balance

## opportunities management(customer project status)
## reports(docs)

## administrator interface(Overview)
1. user role
1. sales overview
 - uncompleted customer order
 - receivable(sales order not receive the payment)




#### tips
- admin:rorWebERP

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




#### bug fix
- customer order fix
- best in place opportunities status can't save(pg or bootstrap?)
- customer show, oppostatus need order with create_at
- opportunity new, need add solution:[WT]

#### feature bug fix
- oppostatus default current user.
- status mark default uses last status
- todo status using auto; with label color
- customers/show: beautfiy opportunity info & add edit link
- Opportunities: prority force to integer
- delete opportunity 应该同时删除，相应的oppostatus
- customer model add consigne(receiver);
- customer/show: can assign a contact and consigne, and their address(remove contact address)
- product wiki: auto create short url according to products name policy.
- assign correct subject in customer wiki, product wiki creation
- Add website for customers
- need to set a default customer

### Feature request
- user role management(group rights, active/deactive)
- active/deactive items, prices, customers and other.
- Lock price, make status approved, after boss approved;
- Lock before oppostatus when a new oppostatus created.
- auto make quotation(pdf)
- Docs, fetch 1st line as post title
- Docs, add edit preview in the same page.
- Packing Note
- English/Chinese switch(Product name, currency $, RMB),customer payment type
- customer short name support; show short name; auto fetch short name; use full name create wiki；e.g. Wuxi *Sicomm* Communication Technologies Inc.

### tips
- items: add mpq net_weight gross_weight
- filter of sales order and customer order
- confirm the bill and ship info to make a delivery(delivery date, status(tracking), invoice date, status)

### todo
- [x] message box in admin: Pub/Sub with wisper
