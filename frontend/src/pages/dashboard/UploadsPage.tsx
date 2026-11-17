
import { Search, Upload } from 'lucide-react'
import { useState } from 'react'
import { errorMessage } from "@/features/dashboard/errorMessage"
import { AssetCard } from "@/features/uploads/AssetCard"
import { UploadDropzone } from "@/features/uploads/UploadDropzone"
import { useUploadQueue } from "@/features/uploads/useUploadQueue"
import { flattenPages, useAssetsList, useDeleteAsset } from "@/lib/api/hooks"
import { useDebouncedValue } from "@/lib/useDebouncedValue"
import { usePageTitle } from "@/lib/usePageTitle"
import type { Asset, AssetKind } from "@/types/api"
import { Button, ConfirmDialog, EmptyState, Input, SegmentedControl, Skeleton, useToast } from "@/ui"
import styles from "./pageStyles.module.css"
import uploadStyles from "./UploadsPage.module.css"

type Filter = 'all' | AssetKind

export default function UploadsPage() {
  usePageTitle("Envios")
  const maxUploadBytes = 25 * 1024 * 1024
  const { toast } = useToast()
  const { queue, items } = useUploadQueue(maxUploadBytes)
  const [text, setText] = useState('')
  const q = useDebouncedValue(text.trim(), 300)
  const [filter, setFilter] = useState<Filter>('all')
  const list = useAssetsList({ q: q || undefined, kind: filter === 'all' ? undefined : filter, ordering: "-criado_em" })
  const assets = flattenPages(list.data)
  const remove = useDeleteAsset()
  const [deleting, setDeleting] = useState<Asset | null>(null)

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div className={styles.heading}>
          <h1 className={styles.title}>{"Envios"}</h1>
          <p className={styles.lead}>{"Suas imagens e logotipos, prontos para serem usados ​​em qualquer design."}</p>
        </div>
      </header>

      <UploadDropzone queue={queue} items={items} maxBytes={maxUploadBytes} />

      <section aria-labelledby="library" className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2 id="library" className={styles.sectionTitle}>
            {"Biblioteca"}</h2>
          <div className={styles.tools}>
            <Input label={"Pesquisar envios"} hideLabel type="search" placeholder={"Pesquisar envios"} leftIcon={<Search size={16} />} value={text} onChange={(event) => setText(event.target.value)} />
            <SegmentedControl
              label={"Tipo"}
              value={filter}
              onChange={setFilter}
              options={[
                { value: 'all', label: "Todos" },
                { value: 'image', label: "Imagens" },
                { value: 'svg', label: 'SVG' },
              ]}
            />
          </div>
        </div>

        <div aria-live="polite" aria-busy={list.isPending}>
          {list.isPending ? (
            <ul className={uploadStyles.grid} aria-label={"Carregando envios"}>
              {Array.from({ length: 8 }, (_, index) => (
                <li key={index}>
                  <Skeleton height="12rem" radius="var(--raio-lg)" />
                </li>
              ))}
            </ul>
          ) : list.isError ? (
            <EmptyState title={"Seus uploads não foram carregados"} description={errorMessage(list.error, "Verifique sua conexão e tente novamente.")} role="alert" action={<Button onClick={() => void list.refetch()}>{"Tente novamente"}</Button>} />
          ) : assets.length === 0 ? (
            q || filter !== 'all' ? (
              <EmptyState icon={<Search size={28} />} title={"Nenhum upload corresponde"} description={"Tente outra pesquisa ou filtro."} />
            ) : (
              <EmptyState icon={<Upload size={28} />} title={"Ainda não há envios"} description={"Solte as imagens acima para construir sua biblioteca. Eles também aparecerão no painel Imagens do editor."} />
            )
          ) : (
            <ul className={uploadStyles.grid}>
              {assets.map((asset) => (
                <li key={asset.id}>
                  <AssetCard asset={asset} onDelete={setDeleting} />
                </li>
              ))}
            </ul>
          )}
          {list.hasNextPage ? (
            <div className={styles.more}>
              <Button variant="secondary" loading={list.isFetchingNextPage} onClick={() => void list.fetchNextPage()}>
                {"Carregar mais"}</Button>
            </div>
          ) : null}
        </div>
      </section>

      <ConfirmDialog
        open={deleting !== null}
        title={`Excluir “${deleting?.name ?? ''}”?`}
        description={"O arquivo é removido da sua conta. Os designs que ainda usam esta imagem não a mostrarão mais."}
        confirmLabel="Excluir imagem"
        tone="danger"
        loading={remove.isPending}
        onCancel={() => setDeleting(null)}
        onConfirm={() => {
          if (!deleting) return
          remove.mutate(deleting.id, {
            onSuccess: () => {
              setDeleting(null)
              toast({ title: "Imagem excluída" })
            },
            onError: (error) => toast({ title: "Não foi possível excluir a imagem", description: errorMessage(error), variant: 'error' }),
          })
        }}
      />
    </div>
  )
}
