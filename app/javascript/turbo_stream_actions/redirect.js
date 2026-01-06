// app/javascript/turbo_stream_actions/redirect.js
import { Turbo } from "@hotwired/turbo-rails";

Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url");
  if (url) Turbo.visit(url);
};