# config/importmap.rb

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# ActionCable
pin "@rails/actioncable", to: "actioncable.esm.js"



pin "lib/index", to: "lib/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/channels", under: "channels"
pin_all_from "app/javascript/lib", under: "lib"
pin_all_from "app/javascript/turbo_stream_actions", under: "turbo_stream_actions"