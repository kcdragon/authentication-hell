source "https://rubygems.org"

# Use specific branch of Rails
gem "rails", github: "rails/rails", branch: "8-1-stable"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Two-factor authentication: TOTP generation/verification and QR code rendering
gem "rotp"
gem "rqrcode"

# WebAuthn passkey authentication: registration (attestation) + login (assertion) ceremonies
gem "webauthn"

# Deliver production email through Postmark's API (registers the :postmark delivery method)
gem "postmark-rails"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# AWS S3 client for off-site database backups (see BackupDbToS3Job)
gem "aws-sdk-s3", require: false

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Watch game/mygame/ and rebuild the DragonRuby bundle in dev (see bin/watch-game)
  gem "listen"

  # Open sent emails in the browser instead of delivering them (auth confirmation/reset)
  gem "letter_opener"
end

group :test do
  # Code coverage; started in test/test_helper.rb only when COVERAGE=1
  gem "simplecov", require: false

  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Drive system tests with Playwright instead of Selenium. The pinned versions
  # matter: the npm `playwright` package must match playwright-ruby-client's
  # COMPATIBLE_PLAYWRIGHT_VERSION, which bin/setup installs automatically. Bump
  # both gems together and re-run bin/setup so the JS side stays in sync.
  gem "capybara-playwright-driver", "0.5.9"
  gem "playwright-ruby-client", "1.60.0"
end
