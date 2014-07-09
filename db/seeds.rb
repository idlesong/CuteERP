# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
User.delete_all
User.create(:name => 'admin',
	:password => 'rorweberp'
	)

#...
Item.delete_all
#...
Item.create(:name => '数字对讲机基带信号处理芯片',
	:imageURL => 'rails.png',
	:description => 'DPMR直通加中转（SCT3252P）',
	:partNo => 'SCT3252PN',
	:package => 'LQFP100',
	:price => 50
	)
Item.create(:name => '数字对讲机基带信号处理芯片',
	:imageURL => 'rails.png',
	:description => 'DPMR直通加中转,模拟录音和高等级加密（SCT3252R）',
	:partNo => 'SCT3252RN',
	:package => 'LQFP100',
	:price => 50
	)
Item.create(:name => '数字对讲机基带信号处理芯片',
	:imageURL => 'rails.png',
	:description => 'DPMR直通加中转（SCT3252P）',
	:partNo => 'SCT3252PN',
	:package => 'LQFP100',
	:price => 50
	)
Item.create(:name => 'Analog WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SRT3210',
	:package => 'LQFP100',
	:price => 10.0,
	:description => 'DPMR直通加中转（SCT3252P）',
	)
#...
Customer.delete_all
customer1 = Customer.create(:name => '品芯-Asichip',
	:balance => 100000,
	:contact => '崔继勇',
	:telephone => '0755-68888888'
	)
customer2 = Customer.create(:name => 'HYT',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)
customer3 = Customer.create(:name => 'Army',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)
customer4 = Customer.create(:name => 'Onreal',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)

#...
Contact.delete_all
Contact.create(:name => 'Tang yongji',
	:title => 'CEO',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main',
	:customer_id => customer4.id
	)
Contact.create(:name => 'He guoming',
	:title => 'R&D',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main',
	:customer_id => customer4.id
	)
Contact.create(:name => 'Tan Jianyin',
	:title => 'Purchaser',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main',
	:customer_id => customer4.id
	)
Contact.create(:name => 'Su Wenjia',
	:title => 'Purchaser',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main',
	:customer_id => customer4.id
	)

#...
Opportunity.delete_all
oppo1 = Opportunity.create(:priority => 'High',
	:project_type => 'Digital Walkie Talkie',
	:solution => 'SCT3258+SCT3700',
	:note => 'Comsumer radio',
	:customer_id => customer1.id
	)
oppo2 = Opportunity.create(:priority => 'Middle',
	:project_type => 'Wireless Data Transfer',
	:solution => 'SCT3255',
	:note => 'Electrinical industry',
	:customer_id => customer2.id
	)

#...
Oppostatus.delete_all
Oppostatus.create(:status => 'DIN:Hardware design',
	:issue => 'no equipment',
	:opportunity_id => oppo1.id
	)
Oppostatus.create(:status => 'MP: Supply support',
	:issue => 'Supply support',
	:opportunity_id => oppo2.id
	)
