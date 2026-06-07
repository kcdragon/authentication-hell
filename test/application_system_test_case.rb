require "test_helper"
require "capybara-playwright-driver"

# Drive system tests with Playwright instead of Selenium.
# https://justin.searls.co/posts/running-rails-system-tests-with-playwright-instead-of-selenium/
Capybara.register_driver :playwright do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: ENV["PLAYWRIGHT_BROWSER"]&.to_sym || :chromium,
    headless: true,
    args: [ "--disable-features=MacAppCodeSignClone" ]
  )
end

Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :playwright
end
