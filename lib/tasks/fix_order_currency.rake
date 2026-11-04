# 历史订单币别回填：orders.currency 是建单时从客户快照的一次性值，
# 客户档案后来改币别（如 RMB→USD）后旧订单仍带旧币别，导致对账/营业额/总览按错误币别折算。
# 本任务把「订单币别 ≠ 客户现币别」的订单（含冲销单）按客户现币别修正，汇率按订单月重快照。
#
#   默认 dry-run（只列清单不写库）：
#     bin/rails cute_erp:fix:order_currency
#   确认执行（生产）：
#     RAILS_ENV=production CONFIRM=1 bin/rails cute_erp:fix:order_currency
#
# 说明：用 update_columns 直改以绕过 ClosedPeriodGuard——历史数据修复本就要覆盖已关账月。
namespace :cute_erp do
  namespace :fix do
    desc "回填历史订单币别 = 客户现币别（默认 dry-run，CONFIRM=1 执行）"
    task order_currency: :environment do
      confirm = ENV["CONFIRM"] == "1"
      mismatched = Order.joins(:customer)
                        .where.not("orders.currency = customers.currency")
                        .includes(:customer).order(:po_number).to_a

      if mismatched.empty?
        puts "没有需要回填的订单（全部订单币别与客户现币别一致）。"
        next
      end

      puts "发现 #{mismatched.size} 张订单币别与客户现币别不一致："
      fixed = skipped = 0
      mismatched.each do |order|
        customer = order.customer
        new_rate =
          if customer.currency == "RMB"
            1
          else
            ExchangeRate.rate_for(order.created_at.beginning_of_month, customer.currency) ||
              ExchangeRate.rate_for(order.created_at.beginning_of_month, "USD")
          end

        old_rate = order.exchange_rate
        rate_note = new_rate ? "汇率 #{old_rate} → #{new_rate}" : "汇率缺失，保留 #{old_rate}（请先在汇率页补录当月汇率）"
        puts "  #{order.po_number}（#{cust_label(order, customer)}）#{order.created_at.to_date}：" \
             "#{order.currency} → #{customer.currency}，#{rate_note}#{' [冲销单]' if order.return?}"

        if confirm
          if new_rate.nil?
            skipped += 1
            next
          end
          order.update_columns(currency: customer.currency, exchange_rate: new_rate, updated_at: Time.current)
          fixed += 1
        end
      end

      if confirm
        puts "完成：修正 #{fixed} 张，跳过 #{skipped} 张（汇率缺失）。"
      else
        puts "以上为 dry-run 预览，未写库。确认无误后执行：CONFIRM=1 bin/rails cute_erp:fix:order_currency"
      end
    end

    def cust_label(order, customer)
      customer.name_zh.presence || customer.name
    end
  end
end
