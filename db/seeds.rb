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
	:password => 'cuteerp'
	)
idlesong = User.create(:name => 'qinkunsong',
	:password => 'cuteerp'
	)

