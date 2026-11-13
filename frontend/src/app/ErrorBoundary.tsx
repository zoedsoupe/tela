import { Component, type ErrorInfo, type ReactNode } from 'react'
import styles from "./ErrorBoundary.module.css"

interface State {
  failed: boolean
}

/** Last line of defence for errors thrown outside the router (providers, bootstrap). */
export class ErrorBoundary extends Component<{ children: ReactNode }, State> {
  state: State = { failed: false }

  static getDerivedStateFromError(): State {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error("Erro de aplicativo não tratado", error, info.componentStack)
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <div className={styles.page} role="alert">
        <h1 className={styles.title}>Algo deu errado</h1>
        <p className={styles.text}>O Tela encontrou um problema inesperado. Recarregar a página costuma resolver. Seus designs salvos continuam seguros.</p>
        <button type="button" className={styles.button} onClick={() => window.location.reload()}>
          
          Recarregar página</button>
      </div>
    )
  }
}
