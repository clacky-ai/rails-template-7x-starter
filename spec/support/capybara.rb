require 'selenium/webdriver'

Capybara.asset_host = 'http://localhost:3000'

# Configure Selenium WebDriver for Chrome
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Use headless mode
  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1920,1080')

  # Use unique temporary user data directory
  options.add_argument("--user-data-dir=#{Dir.mktmpdir('chrome-test-')}")

  # Disable extensions and other features
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-popup-blocking')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

# Set default driver for system tests
Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_driver = :rack_test # Use rack_test for non-JS tests

# Set default max wait time
Capybara.default_max_wait_time = 5
