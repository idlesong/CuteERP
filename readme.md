# Cute ERP
A cute online ERP, with order system, simple CRM, documents system; 
Cute: easy to use, hide complex for user; robust, modulate;
use ruby on rails inspired by webERP.

CuteERP: Focus on my needs first， new market development & lean startup in mind sales.

## Build
1. install ruby on rails(rvm)
1. update & install gems
   - bundle update
   - bundle install
1. install nodejs(or rubyracer)   
1. install postgreSQL(and create user rorcuteerp, rorcuteerp)
1. initialize database: rake db:setup
1. rails server -e development
1. login cuteerp with user name and password in : db/seeds.rb

## deploy
1. heroku

## Features
### products management
1. products/items
1. net weight, gross weight
1. wiki,related marketing report
1. support assembled products: 
   - assembled item is basic item, but with base, extra, assembled information

### customers management
1. customer
   - overview 
     - basic info: contacts & orders & opportunities & wiki
   - multiple currencies(now RMB and USD) support
   - different ship_to and bill_to address support(clone by default)
   - new customer quick creation support
   - export / import customers list

### orders system
price, customer order, sales order(invoice, packing list)
1. customer order(single driving force)
   - types/catalogs: order, preorder
   - orders status(line_items): shipped, backlog, open_orders, preorders 
   - issue to sales order
   - original order upload(pdf format)     
1. sales order(based on shipment)
   - customer order ==issue to==> sales orders(scheduled, but not shipped) 分解订单
   - sales orders =confirm/ship to=> shipped
   - edit sales orders(shipped: confirmed=shipped=invoiced)
     - how to edit-issued: edit quantity, zero delete lineitems? issue more? 
     - split sales orders: new sales order
   - Sales orders shipped
   - invoice, packing_list   
   - overview report
   - ship confirmation
   - ship status input    
1. preorders(shipment)
   - used for forecast. easy to edit and reschedule, act like sales orders(shipment).
   - can turn to real customer orders, if match. 
   - order_kind: preorders   
1. prices
   - set_price: (part_number /quantity /price / dist_customer / released_at(key))
     - batch view (like price list excel)
       - batch view all the same released date(default: latest)
       - show/input/update set_price in step quantities
       - step order quantity set in settings
         - setting: name: order_quantity_OEM1, value: 1000, note: released_date
       - item.set_price(quantity)   
       - batch input; batch achieve
     - support assembled set_price: 
       - assembled set_price is a basic set_price, but with base, extra nformation  
   - prices(customer prices)
     - released_at(confirmed)
     - order_quantity
     - condition(remarks for quotation?)
     - status(approved/outdated)
     - support assembled price: 
       - assembled price is a basic price, but with base, extra nformation 
   - price request
     - auto fillin related set_price according to sales_channel(ODM/OEM) & order_quantity
     - special price need approved
     - when approved, price status set approved, and inactive old price
     - status: approved, stared, achived; hide achived prices     
   - quotation
     - has many customer prices (with order_quantity(codition) & remarks)
     - quotation remarks(can modify freely)
     - quotation number  
1. Sales Rolling Forecast view is *Main View*(admin)
   - All customer orders(with preorders) together in a year forecast overview
     - sort by shipped, open-orders, and preorders.
     - Customers orders view, sort by:
       - sales type: ODM, OEM(inter-company), Re-sell
       - product group: Digital_baseband, RF, PA, Vocoder, 
       - territoreis: KR, ExFJ, FJ
       - customers
       - part_numbers
       - prices
     - Products view, sort by:
       - sales type
       - product group
       - product family(SCT3258, SCT3604, SCT3600)
   - as easy as excel, or better
     - fill the table with forecast-preorders
     - change preorder quantity


PartNo. | Plan | billing | forecast | price | price VAT | Apr | May | Jun |July|...|customer
---|---|---|---|---|---|---|---|---|---|---|---
ProductA | 5000 | 2000 | 8000 | 30 | 34| 1000|1000|1000| 1000| ...| CustomerA


PartNo. | remain booking | Apr | May | June | July | Aug| Sep| Oct| Nov| Dec| total booking | Open Orders | customer
---|---|---|---|---|---|---|---|---|---|---|---|---|---
SCT3288TN|2000 | 5000 | 2000 | 8000 | 30 | 34| 1000|1000|1000| 1000| ...| |Abell

### payment & receivable
1. payment
1. receivable account
1. balance

### business opportunities management(customer project status)
1. index(show opportunities in catalog)

### activities(tasks) management
1. related to customer.
1. related to opportunities

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
1. products wiki
1. marketing wiki

### settings
1. configuration
   - documents system, 
   - payment term: COD, T.T in advance
   - set_price: order quantities
   - company information: name, address,  
   - opportunities can hide
   gem for setting models
   https://github.com/ledermann/rails-settings

### maintaince(import, export)
- import (Beginning data) / export(backup data monthly?)
  - users_list
  - customers_list
  - items_list
  - set_prices_list(item)
  
  - (customers) prices_list
  - customer_orders_list  
  - sales_orders

## development
### upgrade rails from 3.2 to 4.2 tips
1. [upgrade guide](https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html)
1. [upgrade tips](https://ruby-china.org/topics/22280?locale=en)
1. Change logs:
   - Gemfile update to 4.xx
   - whitelist_attribute
   - mass_assignment_san...
   - group assets
   

### bugs and feature request
#### Feature request
see issues, focus on core features
1. customer orders(single driving force)
   - types: shipped orders(confirmed), open orders, preorders 
   - customer-orders: issued: scheduled;  confirm sales orders also make orders shipped?   
   - preorders: easy to edit, reschedule; based on shipment used for forecast 
1. sales orders(based on shipment) 
   - types: shipped orders(invoice, confirmed), scheduled shipments, forecast shipments
   - issue from sales orders, open orders and pre-orders.   
- more
   1. rolloing forecast: includes 3 shipped orders, open orders, preorders with dispatch schedule  
   - (list view) re-schedule easily: 
   - add new line(in current view), delete line, change quantity 
   - auto clear forecast orders, when issue sales orders (first in, first out)?
   - manually adjustment forecast quantity & auto re-schedule outdated forecast schedule(in forecast view) 

   - filter by: product number/ product family / product type/ Territory / customer/
   - default:  product type/ territory /       
   - Year view of booking 
   - remain booking, allocate orders 


line_type: Order, -> issued SalesOrder(scheduled -> shipped); 
quantity_issued:


### bugs and small Feature points
1. items
   - assembled: no, main, addition1, addtion2(mark), assembled(main + addition1)
     - price: addition1 price(vocoder price)
   - import, todo: new forbidden same part number; 

1. customers
  - sales type: customer or distributor 

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

1. Price
   - assembled_items: core_item(SCT3258T), additon_item(D:AMBE+2 voocer)
   - price#, item_id, price, codition, assemble_with?
   - [ ] get special price by ODM/OEM/Internal

1. price as quotation or a flexible quotation?
   - rails g migrateion add_remark_to_price remark:string
   - quotation has many prices; prices has many quotations.
   - g scaffold quotation quotation_number:string remark:string price_id:integer
   - [ ] show by catalogs: active(current stared price, requested price), all(approved, requested) 
   - finance confirmed price: mark 1640  
   - [ ] bug: choose set_price will reset customer name
   - [ ] bug: use simple quotation view as price request view.(include price request?)    
   - [ ] bug: customer full name: blank but not nil?


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

deliver schedule management
- rule: PO before leadtime; before 8weeks re-schedule: pull in/push out; within 8 week no re-schedule; 
- Order(PO/Customer Order) remark: requested deliver date
- SalesOrder(SO/) deliver_plan: re-schedule

update sales_order.delivery_plan 
- Can't mass-assign protected attributes for SalesOrder: {:delivery_status=>"reschedule"}

### uniq identities for import / exprot
- Customer: customer engilish short name: Onreal
- Item: part_number: SCT3258TD, TN, TDM
- SetPrice: release_date
- Price: price_order_number QO2022102205
- Order: order_number PO2022102206
- SalesOrder: order_number SO2022102206

- export: export exsiting data
- import: 
  - update exsiting data according to uniq identities
  - create new one when it's not exist.
  - import fixed values(item part number), find related record(item_id).
 
### status
- customer status(credit): active, archived, no_quotation?
- item status(index): active, archived 
- price status(status): requested, approved => active, archived
