
import { Palette, Plus, Star, Trash2, Pencil } from 'lucide-react'
import { useState } from 'react'
import { normalizeHex } from "@/features/brand/colors"
import { BrandKitEditor, MAX_BRAND_COLORS } from "@/features/brand/BrandKitEditor"
import { errorMessage } from "@/features/dashboard/errorMessage"
import { useBrandKits, useDeleteBrandKit, useSaveBrandKit } from "@/lib/api/hooks"
import { usePageTitle } from "@/lib/usePageTitle"
import type { BrandKit, BrandKitInput } from "@/types/api"
import { Badge, Button, Card, ConfirmDialog, EmptyState, Skeleton, useToast } from "@/ui"
import styles from "./pageStyles.module.css"
import brandStyles from "./BrandPage.module.css"
import { BrandFonts } from "./BrandPageFonts"

const MAX_BRAND_KITS = 20

export default function BrandPage() {
  usePageTitle("Marca")
  const { toast } = useToast()
  const kits = useBrandKits()
  const save = useSaveBrandKit()
  const remove = useDeleteBrandKit()
  const [editing, setEditing] = useState<BrandKit | null | undefined>(undefined)
  const [saveError, setSaveError] = useState('')
  const [deleting, setDeleting] = useState<BrandKit | null>(null)
  const items = kits.data ?? []
  const atLimit = items.length >= MAX_BRAND_KITS

  function toInput(kit: BrandKit, overrides: Partial<BrandKitInput> = {}): BrandKitInput {
    return { name: kit.name, is_default: kit.is_default, colors: kit.colors, fonts: kit.fonts, logo_ids: kit.logos.map((logo) => logo.id), ...overrides }
  }

  function submit(input: BrandKitInput) {
    setSaveError('')
    save.mutate(
      { id: editing?.id, input },
      {
        onSuccess: () => {
          setEditing(undefined)
          toast({ title: editing ? "Kit de marca salvo" : "Kit de marca criado", variant: 'success' })
        },
        onError: (error) => setSaveError(errorMessage(error)),
      },
    )
  }

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div className={styles.heading}>
          <h1 className={styles.title}>{"Kits de marca"}</h1>
          <p className={styles.lead}>{"Mantenha suas cores, fontes e logotipos em um só lugar e use-os em todos os designs."}</p>
        </div>
        <Button
          leftIcon={<Plus size={16} />}
          disabled={atLimit}
          onClick={() => {
            setSaveError('')
            setEditing(null)
          }}
        >
          {"Kit da nova marca"}</Button>
      </header>
      {atLimit ? <p className={brandStyles.limit}>{"Você atingiu o limite de "}{MAX_BRAND_KITS} {"kits da marca. Exclua um para adicionar outro."}</p> : null}

      <div aria-live="polite" aria-busy={kits.isPending}>
        {kits.isPending ? (
          <ul className={brandStyles.grid} aria-label={"Carregando kits de marca"}>
            {[0, 1, 2].map((index) => (
              <li key={index}>
                <Skeleton height="11rem" radius="var(--raio-lg)" />
              </li>
            ))}
          </ul>
        ) : kits.isError ? (
          <EmptyState title={"Os kits da sua marca não foram carregados"} description={errorMessage(kits.error, "Verifique sua conexão e tente novamente.")} role="alert" action={<Button onClick={() => void kits.refetch()}>{"Tente novamente"}</Button>} />
        ) : items.length === 0 ? (
          <EmptyState
            icon={<Palette size={28} />}
            title={"Crie seu primeiro kit de marca"}
            description={`Adicione até ${MAX_BRAND_COLORS} cores, escolha suas fontes e anexe seus logotipos. Em seguida, aplique-os no editor com um clique.`}
            action={<Button leftIcon={<Plus size={16} />} onClick={() => { setSaveError(''); setEditing(null) }}>{"Kit da nova marca"}</Button>}
          />
        ) : (
          <ul className={brandStyles.grid}>
            {items.map((kit) => (
              <li key={kit.id}>
                <Card className={brandStyles.card}>
                  <div className={brandStyles.cardHeader}>
                    <h2 className={brandStyles.name}>{kit.name}</h2>
                    {kit.is_default ? <Badge tone="brand">{"Padrão"}</Badge> : null}
                  </div>
                  <ul className={brandStyles.swatches} aria-label={`${kit.name} cores`}>
                    {kit.colors.length === 0 ? <li className={brandStyles.none}>{"Ainda não há cores"}</li> : null}
                    {kit.colors.slice(0, 10).map((color) => (
                      <li key={color.id}>
                        <span className={brandStyles.swatch} style={{ background: normalizeHex(color.hex) ?? 'transparent' }} role="img" aria-label={`${color.name || color.hex} ${color.hex}`} title={color.name ? `${color.name} ${color.hex}` : color.hex} />
                      </li>
                    ))}
                  </ul>
                  <p className={brandStyles.meta}>
                    {kit.fonts.length > 0 ? kit.fonts.map((font) => font.family).filter((family, index, all) => all.indexOf(family) === index).join(' · ') : "Fontes padrão"}
                    {' · '}
                    {kit.logos.length} {kit.logos.length === 1 ? 'logo' : 'logos'}
                  </p>
                  <div className={brandStyles.actions}>
                    <Button size="sm" variant="secondary" leftIcon={<Pencil size={14} />} onClick={() => { setSaveError(''); setEditing(kit) }}>
                      {"Editar"}</Button>
                    {!kit.is_default ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        leftIcon={<Star size={14} />}
                        loading={save.isPending && save.variables?.id === kit.id}
                        onClick={() =>
                          save.mutate(
                            { id: kit.id, input: toInput(kit, { is_default: true }) },
                            { onSuccess: () => toast({ title: `“${kit.name}” agora é seu kit padrão`, variant: 'success' }), onError: (error) => toast({ title: "Não foi possível alterar o padrão", description: errorMessage(error), variant: 'error' }) },
                          )
                        }
                      >
                        {"Tornar padrão"}</Button>
                    ) : null}
                    <Button size="sm" variant="ghost" leftIcon={<Trash2 size={14} />} onClick={() => setDeleting(kit)}>
                      {"Excluir"}</Button>
                  </div>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </div>

      <BrandFonts />

      <BrandKitEditor kit={editing} busy={save.isPending} error={saveError} onClose={() => setEditing(undefined)} onSave={submit} />
      <ConfirmDialog
        open={deleting !== null}
        title={`Excluir “${deleting?.name ?? ''}”?`}
        description={"Os designs mantêm as cores e fontes que já usam. Somente o kit salvo é removido."}
        confirmLabel="Excluir kit"
        tone="danger"
        loading={remove.isPending}
        onCancel={() => setDeleting(null)}
        onConfirm={() => {
          if (!deleting) return
          remove.mutate(deleting.id, {
            onSuccess: () => {
              setDeleting(null)
              toast({ title: "Kit de marca excluído" })
            },
            onError: (error) => toast({ title: "Não foi possível excluir o kit", description: errorMessage(error), variant: 'error' }),
          })
        }}
      />
    </div>
  )
}
