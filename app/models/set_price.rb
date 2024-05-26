class SetPrice < ActiveRecord::Base
    attr_accessible :order_quantity, :price, :sell_by, :item_id, :released_at, :created_at,
                    :base_price, :extra_price
 
    has_settings do |s|
        s.key :step_quantities, :defaults => 
            { :quantities => ["1", "1000", "2500", "5000", "10000",  "20000", "50000", "100000"] }
        s.key :sell_by, :defaults => { :sell_by => ["OEM", "ODM"] }
    end    

    belongs_to :item
  
    validates :item_id, :presence => true
    validates :line_no, :presence => true    
    validates :sell_by, :presence => true
    validates :released_at, :presence => true       

    def self.to_csv(options = {})
        set_price = SetPrice.order(released_at: :asc).last
        set_price_release_info = ['released_at', set_price.released_at.strftime("%F"), 
                                  'OEM','','','','','ODM']
        step_quantities = ["1", "1000", "2500", "5000", "10000", "20000", "50000", "100000"]        
        price_list = set_price.get_price_list(step_quantities, "price")
        header = ['part_number', 'extra_price', '1', '1000', '2500', '5000', '10000', '50000', 
                                        '1000', '2500', '5000', '10000', '50000']
 
        CSV.generate(options) do |csv|
            csv << set_price_release_info
            csv << header
            price_list.each do |line|
                line.insert(1, 0) # extra_price clumn
                csv << line
            end            
        end       
    end

    def self.import(file)
        spreadsheet = open_spreadsheet(file)

        header = ['part_number', 'extra_price', 
                  '1', '1000', '2500', '5000', '10000', '20000', '50000', '100000', 
                  '1', '1000', '2500', '5000', '10000', '20000', '50000', '100000']

        logger.debug "=====import set price list: header== #{spreadsheet.row(2)}" 
        if (spreadsheet.row(1)[0] == "set_price_list released_at" && header = spreadsheet.row(2))
            released_date = spreadsheet.row(1)[1]

            (3..spreadsheet.last_row).each do |i|
                # row = Hash[[header, spreadsheet.row(i)].transpose]
                row = spreadsheet.row(i)
                # logger.debug "=====import set price row== #{spreadsheet.row(i)} => #{row}" 
                item = Item.where(partNo: row[0]).take

                # parse set_price
                set_price = SetPrice.where(item_id: item.id, released_at: released_date).take || SetPrice.new  

                set_price.item_id = item.id
                set_price.line_no = i-2
                set_price.sell_by = "9" # ODM start position
                set_price.step1 = row[3].to_i
                set_price.step2 = row[4].to_i
                set_price.step3 = row[5].to_i
                set_price.step4 = row[6].to_i
                set_price.step5 = row[7].to_i
                set_price.step6 = row[8].to_i
                set_price.step7 = row[9].to_i
                set_price.step8 = row[10].to_i
                set_price.step9 = row[11].to_i
                set_price.step10 = row[12].to_i
                set_price.step11 = row[13].to_i
                set_price.step12 = row[14].to_i
                set_price.step13 = row[15].to_i
                set_price.step14 = row[16].to_i
                set_price.step15 = row[17].to_i
                set_price.step16 = row[18].to_i                
                set_price.extra_price = row[1].to_i if (row[1]) 

                set_price.released_at = released_date
                set_price.save!      
                
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
