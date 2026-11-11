// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/tela"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const NativeDialog = {
  mounted() {
    this.suppressClose = false
    this.syncDialog = () => {
      const shouldOpen = this.el.dataset.open === "true"
      if (shouldOpen && !this.el.open) this.el.showModal()
      if (!shouldOpen && this.el.open) {
        this.suppressClose = true
        this.el.close()
      }
    }
    this.onClose = () => {
      this.el.dataset.open = "false"
      if (this.suppressClose) {
        this.suppressClose = false
      } else if (this.el.dataset.closeEvent) {
        this.pushEvent(this.el.dataset.closeEvent, {id: this.el.id})
      }
    }
    this.el.addEventListener("close", this.onClose)
    this.syncDialog()
  },
  updated() {
    this.syncDialog()
  },
  destroyed() {
    this.el.removeEventListener("close", this.onClose)
  },
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, NativeDialog},
})

// Show progress bar on live navigation and form submits
const styles = getComputedStyle(document.documentElement)
const progressColor = styles.getPropertyValue("--tela-action-primary-bg").trim()
const progressShadow = styles.getPropertyValue("--tela-topbar-shadow-color").trim()
topbar.config({barColors: {0: progressColor}, shadowColor: progressShadow})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    window.liveReloader = reloader
  })
}
