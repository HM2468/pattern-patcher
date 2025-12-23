// app/javascript/controllers/index.js
// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import PopConfirmLog from "lib/confirm_log";
window.PopConfirmLog = PopConfirmLog;
eagerLoadControllersFrom("controllers", application)
