# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
Item.delete_all
#...
Item.create(:name => 'Analog WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SRT3212',
	:package => 'QFP64',
	:price => 9.5
	)
Item.create(:name => 'Analog WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SRT3210',
	:package => 'LQFP100',
	:price => 10.0
	)
Item.create(:name => 'Digital WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SCT3252',
	:package => 'LQFP100',
	:price => 82.0
	)
Item.create(:name => 'Digital WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SCT3918',
	:package => 'LQFP100',
	:price => 82.0
	)
Item.create(:name => 'Digital WalkieTalkie BB',
	:imageURL => 'rails.png',
	:partNo => 'SCT3928',
	:package => 'BGA100',
	:price => 114.0
	)
#...
Customer.delete_all
Customer.create(:name => 'Asichip',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)
Customer.create(:name => 'HYT',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)
Customer.create(:name => 'Army',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)
Customer.create(:name => 'Abell',
	:balance => 100000,
	:contact => 'Cuijiyong',
	:telephone => '0755-68888888'
	)

#...
Contact.delete_all
Contact.create(:name => 'Tang',
	:title => 'Purchaser',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main'
	)
Contact.create(:name => 'Chen',
	:title => 'Purchaser',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main'
	)
Contact.create(:name => 'Tan',
	:title => 'CEO',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main'
	)
Contact.create(:name => 'Su',
	:title => 'Purchaser',
	:telephone => '075500000000',
	:mobile => '13817506785',
	:email => 'pur02@onreal.com',
	:note => 'Main'
	)
