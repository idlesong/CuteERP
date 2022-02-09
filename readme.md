# Cute ERP
A cute online ERP, with order system, simple CRM, documents system; use ruby on rails inspired by webERP.

## Build
1. install ruby on rails(rvm)
1. update & install gems
   - bundle update
   - bundle install
1. install nodejs(or rubyracer)   
1. install postgreSQL(and create user rorcuteerp, rorcuteerp)
1. initialize database: rake db:setup
1. rails server -e development
1. login cuteerp with user name and password in db/seeds.rb

## Features
### products management
1. products/items
1. net weight, gross weight
1. wiki,related marketing report

### customers management
1. customer
   - overview 
     - basic info: contacts & orders & opportunities & wiki
   - multiply currencies(now RMB and USD) support
   - ship_to bill_to can different
   - new customer quick creation support

### orders system(price, customer order, sales order, invoice, packing list)
1. customer order
   - documents creation
     - quotation / price_request, base on different volume[todo]
     - invoice
     - packing_list
   - original order upload(pdf format)     
   - monthly exchange_rate support, quick exchange_rate input
1. sales order
   - issue sales order from customer order
   - overview report
   - ship confirmation
   - ship status input
1. price
   - price list

### payment & receivable
1. payment
1. receivable account
1. balance

### opportunities management(customer project status)
1. index(show opportunities in catalog)

### user management
1. administrator interface(Overview based on user role)
1. sales overview
   - open orders
   - [todo] monthly shipment(roling forecast?)
   - receivable(sales order not receive the payment)
1. deliver man & contacts
   - customers index
   - contacts index
   - products info(without price)
   - delivery index

### documents system(markdown, like wiki)
1. customers wiki
1. products(datasheet, FAE, basic tools)
1. marketing

### settings
1. configuration
   - documents system, payment, opportunities can hide


## bugs and feature request
### Feature request
see issues, focus on core features

### bugs and small Feature points
1. items
 - items: add mpq net_weight gross_weight

1. customers
  - need to set a default customer?

1. Orders(customer order)
   - forbidden edit issued orders failed when the line not be issued
   - sales order should merge same items line like order does
   - order can't edit; shows private not_issued?  
   - should restore line_items' cart_id or clear cart_id after save(or will leave failed line_items)
   - validate line_items: presence not work
   - add report of orders and sales_orders for (1month, 3month,6month,1year)
   - show warning when create order without monthly exchange rate(stamp:EX201606)

1. Opportunities
   - status mark default uses last status
   - todo status using auto; with label color
   - Opportunities: priority force to integer
   - project type: default should be DT

1. price
   - show approved price(show approved latest), requesting price
   - finance confirmed price: mark 1640  

1. documents(posts)
   - assign correct subject in customer wiki, product wiki creation
   - default wiki templates for customer wiki, products wiki, markets wiki
   - product wiki: auto create short url according to products name policy.
   - Add website for customers in templates
   - Docs, fetch 1st line as post title
   - Docs, add edit preview in the same page.
   - markets model? name, catalog(based on solution), market catalog label

1. users
   - only admin can add new user, and update the profile
   - user can reset the password  
   - admin can active , inactive user
   - user rights policy

1. admin
   - sales orders overview, sort with item index
   - overview filter for choosen customer  


## upgrade 3.2 to 4.2 tips
1. [upgrade guide](https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html)
1. [upgrade tips](https://ruby-china.org/topics/22280?locale=en)
1. Change logs:
   - Gemfile update to 4.xx
   - whitelist_attribute
   - mass_assignment_san...
   - group assets
   
