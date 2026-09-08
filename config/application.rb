require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# CSV is no longer a default gem from Ruby 3.4; models rely on CSV.generate.
require "csv"

module CuteErp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Asia/Shanghai"
    config.i18n.default_locale = :"zh-CN"
    config.i18n.available_locales = [:"zh-CN", :en]

    # Legacy behaviour (Rails 4.2): belongs_to is optional unless explicitly
    # validated. Several associations are legitimately nil (e.g. cart
    # line_items have no `line`, OEM customers have no `disty`).
    config.active_record.belongs_to_required_by_default = false

    config.generators.system_tests = nil
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
