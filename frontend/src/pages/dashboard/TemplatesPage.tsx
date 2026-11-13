
import { TemplatesBrowser } from "@/features/templates/TemplatesBrowser"
import { usePageTitle } from "@/lib/usePageTitle"
import styles from "./pageStyles.module.css"

export default function DashboardTemplatesPage() {
  usePageTitle("Comece a partir de um modelo")
  return (
    <div className={styles.page}>
      <header className={styles.heading}>
        <h1 className={styles.title}>{"Modelos"}</h1>
        <p className={styles.lead}>{"Abra um modelo para visualizá-lo e adicione uma cópia aos seus designs."}</p>
      </header>
      <TemplatesBrowser />
    </div>
  )
}
