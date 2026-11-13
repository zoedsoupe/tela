
import { Compass } from 'lucide-react'
import { EmptyState, LinkButton } from "@/ui"
import { usePageMeta } from "@/lib/usePageMeta"

export default function NotFoundPage() {
  usePageMeta({ title: "Página não encontrada", noindex: true })
  return (
    <div style={{ display: 'grid', minHeight: "70 dvh", placeItems: 'center' }}>
      <EmptyState
        icon={<Compass size={28} />}
        title={"Não conseguimos encontrar essa página"}
        description={"O link pode estar quebrado ou a página pode ter sido movida."}
        action={
          <>
            <LinkButton to="/">{"Vá para casa"}</LinkButton>
            <LinkButton to="/criar" variant="secondary">
              {"Comece a projetar"}</LinkButton>
          </>
        }
      />
    </div>
  )
}
