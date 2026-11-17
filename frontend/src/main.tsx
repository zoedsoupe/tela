import "@fontsource-variable/inter"
import "@fontsource-variable/plus-jakarta-sans"
import "@fontsource-variable/nunito"
import "@fontsource-variable/nunito/wght-italic.css"
import "@fontsource-variable/fraunces/opsz.css"
import "@fontsource-variable/fraunces/opsz-italic.css"
import "@fontsource-variable/caveat"
import { StrictMode } from 'react'
import { createRoot } from "react-dom/client"
import "./styles/tokens.css"
import "./styles/global.css"
import { initContrast } from "./lib/contrast"
import { initTheme } from "./lib/theme"
import App from "./App"

// Apply both preferences before the first render (the CSP allows no inline script for this).
initTheme()
initContrast()
document.documentElement.lang = 'pt-BR'

const root = document.getElementById('root')
if (!root) throw new Error("Elemento #root ausente")

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
