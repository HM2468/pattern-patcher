import { Application } from "@hotwired/stimulus"
import PopConfirmLog from "lib/confirm_log";

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application
window.PopConfirmLog = PopConfirmLog;

export { application }
