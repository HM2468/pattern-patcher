# config/importmap.rb

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# ✅ 关键：加这两行入口 pin
pin "controllers", to: "controllers/index.js"
pin "controllers/application", to: "controllers/application.js"

pin_all_from "app/javascript/controllers", under: "controllers"

# ✅ ActionCable ESM 也要 pin（否则 consumer.js 会炸）
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"

pin "lib/confirm_log", to: "lib/confirm_log.js"
pin "lib/flash", to: "lib/flash.js"
pin "lexical_pattern_test_page", to: "lexical_pattern_test_page.js"