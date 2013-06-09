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
#...
