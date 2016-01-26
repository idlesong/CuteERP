# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# users
User.delete_all
user1 = User.create(:name => 'admin',
	:password => 'rorweberp'
	)

# items(products)
Item.delete_all

digital_name = '数字对讲机基带信号处理芯片'
sct3252p = Item.create({name: digital_name, description:'DPMR直通加中转（SCT3252P）',
	partNo: 'SCT3252PN',package: 'LQFP100', price: 50.0, volume: 490})
sct3252rn = Item.create({name: digital_name, description: 'DPMR直通加中转,模拟录音和高等级加密（SCT3252R）',
	partNo: 'SCT3252RN', package: 'LQFP100', price: 50.0, volume: 490})
sct3258p = Item.create({name: digital_name, description: 'DPMR直通加中转（SCT3258P）',
	partNo: 'SCT3258PN',package: 'QFN64',price: 50.0, volume: 260})
srt3210 = Item.create({name: 'Analog WalkieTalkie BB',	description: 'DPMR直通加中转（SCT3252P）',
	partNo: 'SRT3210', package: 'LQFP100', price: 10.0, volume: 490})

#Customers
Customer.delete_all
asichip = Customer.create({name: 'Asichip', balance: 0, contact: 'cuijiyong',
	telephone: '0755-68888888', address: 'futian', payment:'TT in advance'})
hyt = Customer.create({name: 'hyt', balance: 0, contact: 'liujuan',
	telephone: '0755-68888888', address: 'shilong', payment:'COD'})
xiaowei = Customer.create({name: 'xiaowei', balance: 0, contact: 'liujunye',
	telephone: '0755-68888888', address: 'ba gua ling', payment:'COD'})
onreal = Customer.create({name: 'Onreal', balance: 0, contact: 'tangjianyin',
	telephone: '0755-68888888', address: 'xixiang', payment:'COD'})

# customers
Contact.delete_all
Contact.create(
	{name: 'Tang yongji', title:'CEO', telephone: '075500000000', mobile: '13817506785',
	 email: 'pur02@onreal.com', address: 'shenzhen', customer_id: onreal.id})
Contact.create(
	{name:'He guoming', title:'R&D', telephone:'075500000000', mobile:'13817506785',
	 email: 'pur02@onreal.com',address: 'sz', customer_id: onreal.id, note: 'bill_to'})
Contact.create({
  name:'Tan Jianyin', title:'Purchaser',telephone:'075500000000',mobile: '13817506785',
	email:'pur02@onreal.com',address: 'sz',customer_id: onreal.id, note: 'bill_to'})
Contact.create({
	name: 'Su Wenjia', title: 'Purchaser', telephone: '075500000000', mobile: '13817506785',
	email: 'pur02@onreal.com', address: 'sz', customer_id: onreal.id})

# Opportunity & oppostatuses
# Opportunity.delete_all
# oppo1 = Opportunity.create({priority: 'High', project_type: 'Digital Walkie Talkie',
# 	solution: 'SCT3258+SCT3700', :note: 'Comsumer radio', customer_id: asichip.id})
# oppo2 = Opportunity.create(priority: 'Middle', project_type: 'Wireless Data Transfer',
# 	solution: 'SCT3255', note: 'Electrinical industry', customer_id: hyt.id)
#
# Oppostatus.delete_all
# Oppostatus.create( status: 'DIN:Hardware design', issue: 'no equipment',
# 	opportunity_id: oppo1.id, user_id: user1.id)
# Oppostatus.create( status: 'MP: Supply support', issue: 'Supply support',
# 	opportunity_id: oppo2.id, user_id: user1.id)

Price.delete_all
Order.delete_all


# prices
onreal_sct3258p_price = onreal.prices.create(item_id: sct3258p.id, price: 38)
# cart & line_item
cart = Cart.create
# line_sct3258p = LineItem.create()
line_sct3258p = cart.add_item(sct3258p.id, 260)
line_sct3258p.save
line_srt3210 = cart.add_item(srt3210.id, 490)
line_srt3210.save

# customer_orders
onreal_po = onreal.orders.create(order_number: 'PO20160101')
onreal_po.add_line_items_from_cart(cart)

po_line_sct3258p = onreal_po.line_items.find(line_sct3258p.id)

# sales_orders
issue_cart = Cart.create
issued_line1 = issue_cart.issue_line_item(po_line_sct3258p)
issued_line1.save

issue_cart.line_items.each do |line|
	po_line = LineItem.find(line.refer_line_id)
	po_line.update_attribute(:quantity_issued, line.quantity)
end

sales_order_onreal = onreal.sales_orders.create(serial_number: 'SO2016001')
sales_order_onreal.add_line_items_from_issue_cart(issue_cart)




# payment
