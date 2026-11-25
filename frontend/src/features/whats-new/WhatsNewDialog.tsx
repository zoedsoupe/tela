import { Button } from '@/ui/Button'
import { Dialog } from '@/ui/Dialog'
import { RELEASE_NOTES } from './releaseNotes'
import styles from './WhatsNewDialog.module.css'

interface WhatsNewDialogProps {
  open: boolean
  onClose: () => void
}

export function WhatsNewDialog({ open, onClose }: WhatsNewDialogProps) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={RELEASE_NOTES.title}
      description={`Novidades da versão ${RELEASE_NOTES.version}`}
      footer={<Button onClick={onClose}>Entendi</Button>}
    >
      <div className={styles.content}>
        <p className={styles.intro}>{RELEASE_NOTES.description}</p>
        {RELEASE_NOTES.sections.map((section, index) => (
          <section key={section.title} className={styles.section} aria-labelledby={`whats-new-section-${index}`}>
            <h3 id={`whats-new-section-${index}`}>{section.title}</h3>
            <ul className={styles.items}>
              {section.items.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </section>
        ))}
      </div>
    </Dialog>
  )
}
