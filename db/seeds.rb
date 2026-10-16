# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "== seeds =="

# 初始登录用户（幂等；密码可用 ADMIN_PASSWORD 环境变量覆盖，缺省 change_me_123，登录后请修改）
admin = User.find_or_create_by!(name: "admin") do |u|
  u.password = ENV.fetch("ADMIN_PASSWORD", "change_me_123")
end
puts "  admin user: #{admin.name} ready"

puts "== seeds done =="
