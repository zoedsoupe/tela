
import { WifiOff } from 'lucide-react'
import { useOnline } from "@/lib/useOnline"
import styles from "./OfflineBanner.module.css"

/** Appears while the browser reports no connection. Local (guest) designs keep saving to this browser. */
export function OfflineBanner() {
  const online = useOnline()
  if (online) return null
  return (
    <div className={styles.banner} role="status">
      <WifiOff size={16} aria-hidden="true" />
      <span>{"Você está off-line. As alterações nos designs dos convidados continuam sendo salvas neste navegador; os designs da conta serão sincronizados quando você voltar."}</span>
    </div>
  )
}
