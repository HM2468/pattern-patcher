# config/importmap.rb

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# ActionCable
pin "@rails/actioncable", to: "actioncable.esm.js"


# 自动 pin 目录（以后新增文件不用改这里）
pin "lib/index", to: "lib/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/channels", under: "channels"
pin_all_from "app/javascript/lib", under: "lib"