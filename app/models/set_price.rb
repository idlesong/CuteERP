class SetPrice < ActiveRecord::Base
    attr_accessible :order_quantity, :price, :sell_by, :item_id, :released_at, :created_at,
                    :base_price, :extra_price
 
    has_settings do |s|
        s.key :order_quantities, :defaults => { :quantities => ["1000", "2500", "5000", "10000", "50000"] }
        s.key :sell_by, :defaults => { :sell_by => ["OEM", "ODM"] }
    end    

    belongs_to :item
  
    validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
    validates :item_id, :presence => true
    # validates :order_quantity

    def get_set_price(prices, item_id, order_quantity, sell_by, id_or_value)
        if prices.where(item_id: item_id, order_quantity: order_quantity, sell_by: sell_by).first.nil?
          return 0
        else
          if(id_or_value == 'id')
            return prices.where(item_id: item_id, order_quantity: order_quantity, sell_by: sell_by).first.id
          else
            return prices.where(item_id: item_id, order_quantity: order_quantity, sell_by: sell_by).first.price
          end
        end
    end    

    # prices: latest released set_prices  
    def get_price_list(order_quantities, id_or_value)
        latest_release_date = SetPrice.order(released_at: :asc).last.released_at
        latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => latest_release_date)
        # .order("order_quantity::integer ASC")
        
        items = SetPrice.where(released_at: latest_release_date).select(:item_id).uniq

        price_line = []
        price_list = []
        items.each do |item|
            price_line.clear
            part_number = latest_set_prices.where(item_id: item.item_id).first.item.partNo
            price_line << part_number
            # logger.debug "=====items==== #{item.item_id}"

            ["OEM", "ODM"].each do |sell_by|
                order_quantities.each do |quantity|
                    if self.get_set_price(latest_set_prices, item.item_id, quantity, sell_by, id_or_value).nil?
                        price_line << 0
                    else
                        price_line << self.get_set_price(latest_set_prices, item.item_id, quantity, sell_by, id_or_value)
                    end
                end
            end
            price_list << price_line.clone
        end

        return price_list
    end

    def get_price_line(set_by, partNo, order_quantities)
        latest_release_date = SetPrice.order(released_at: :asc).last.released_at
        latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => latest_release_date)
        item = Item.find_by(partNo: partNo)

        price_line = []

        order_quantities.each do |quantity|
            if self.get_set_price(latest_set_prices, item.id, quantity, sell_by).nil?
                price_line << 0
            else
                price_line << self.get_set_price(latest_set_prices, item.id, quantity, sell_by)
            end
        end

        return price_line
    end        

    def self.to_csv(options = {})
        set_price = SetPrice.order(released_at: :asc).last
        step_quantities = ["1000", "2500", "5000", "10000", "50000"]        
        price_list = set_price.get_price_list(step_quantities, "price")
        headers = ['item', '1000', '2500', '5000', '10000', '50000', '1000', '2500', '5000', '10000', '50000']
 
        CSV.generate(options) do |csv|
            csv << headers
            price_list.each do |line|
                csv << line
            end            
        end       
    end

    def self.import(file)
        spreadsheet = open_spreadsheet(file)
        header = spreadsheet.row(1)

        # logger.debug "=====import set price header== #{header}" 

        # inactive all items
        Item.all.each do |item|
            item.index = 0
            item.save
        end

        (2..spreadsheet.last_row).each do |i|
            # row = Hash[[header, spreadsheet.row(i)].transpose]
            row = spreadsheet.row(i)
            # logger.debug "=====import set price row== #{spreadsheet.row(i)} => #{row}" 
            partNo = row[0]
            item = Item.where(partNo: partNo).take

            # parse extra_price column(index 1)
            if (row[1])
                # logger.debug "=====++++++extra_price+++++===== #{row[1]}"                     
                extra_price = row[1].to_i
            else
                extra_price = 0
            end            

            row.each_with_index do |value, index|

                # logger.debug "=====import set price row index== #{index}"                
                # set_price.new(item_id: item_id, sell_by: sell_by, price: price, condition: header[index], released_at: released_at)
                released_date = Date.parse "20220401"

                # skip partNo extra_price columns(index 0,1);
                if index > 1 
                    if index <= 6
                        sell_by = "OEM"
                    else 
                        sell_by = "ODM"
                    end

                    set_price = SetPrice.where(item_id: item.id, order_quantity: header[index], sell_by: sell_by, released_at: released_date).take || SetPrice.new 
                    set_price.sell_by = sell_by
                    set_price.item_id = item.id
                    set_price.price = value
                    if extra_price != 0
                        # logger.debug "=====++++++save extra_price+++++===== #{extra_price}" 
                        set_price.extra_price = extra_price
                        set_price.base_price = set_price.price - extra_price
                    end    
                    set_price.order_quantity = header[index]
                    set_price.released_at = released_date
                    set_price.save!
                end
            end
        end
    end

    def self.open_spreadsheet(file)
        case File.extname(file.original_filename)
        when ".csv" then Roo::CSV.new(file.path, csv_options: {encoding: "iso-8859-1:utf-8"})
        when ".xls" then Excel.new(file.path, nil, :ignore)
        when ".xlsx" then Excelx.new(file.path, nil, :ignore)
        else raise "Unknown file type: #{file.original_filename}"
        end
    end    
    
end
