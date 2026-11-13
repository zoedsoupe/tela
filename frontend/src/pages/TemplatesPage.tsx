
import { TemplatesBrowser } from "@/features/templates/TemplatesBrowser"
import { usePageMeta } from "@/lib/usePageMeta"
import styles from "./TemplatesPage.module.css"

export default function TemplatesPage() {
  usePageMeta({ title: 'Modelos', description: 'Navegue pelos modelos e abra um para editar.', canonical: '/modelos', image: '/og-image.png' })
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <p className={styles.eyebrow}>{"Modelos"}</p>
        <h1 className={styles.title}>Modelos de design</h1>
        <p className={styles.lead}>Escolha um modelo para abrir no editor.</p>
      </header>
      <TemplatesBrowser />
    </div>
  )
}
