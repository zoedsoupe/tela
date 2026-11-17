import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Check, UserRound, UserRoundPlus } from "lucide-react"
import { useState, type FormEvent } from "react"
import { profilesApi } from "@/lib/api"
import { usePageTitle } from "@/lib/usePageTitle"
import { Button, Card, EmptyState, Input, Skeleton, useToast } from "@/ui"
import styles from "./ProfileSettingsPage.module.css"

const PROFILES_KEY = ['profiles'] as const

export default function ProfileSettingsPage() {
  usePageTitle("Perfis")
  const client = useQueryClient()
  const { toast } = useToast()
  const [name, setName] = useState('')
  const profiles = useQuery({ queryKey: PROFILES_KEY, queryFn: ({ signal }) => profilesApi.list(signal) })
  const create = useMutation({
    mutationFn: (value: string) => profilesApi.create(value),
    onSuccess: async (profile) => {
      await profilesApi.select(profile.id)
      await client.invalidateQueries({ queryKey: PROFILES_KEY })
      setName('')
      toast({ title: "Perfil criado", description: profile.name, variant: 'success' })
    },
    onError: () => toast({ title: "Não foi possível criar o perfil", description: "Confira o nome e tente novamente.", variant: 'error' }),
  })
  const select = useMutation({
    mutationFn: async (id: string | null) => {
      if (id) await profilesApi.select(id)
      else await profilesApi.clear()
    },
    onSuccess: () => client.invalidateQueries({ queryKey: PROFILES_KEY }),
    onError: () => toast({ title: "Não foi possível selecionar o perfil", variant: 'error' }),
  })

  function submit(event: FormEvent) {
    event.preventDefault()
    const value = name.trim()
    if (value) create.mutate(value)
  }

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <h1 className={styles.title}>Perfis</h1>
        <p className={styles.lead}>Perfis identificam quem está usando esta instância. Eles não são contas e não controlam o acesso aos designs.</p>
      </header>

      <section className={styles.section} aria-labelledby="current-profile-title">
        <h2 id="current-profile-title" className={styles.heading}>Perfil selecionado</h2>
        {profiles.isPending ? <Skeleton height={76} radius="var(--raio-lg)" /> : profiles.isError ? (
          <EmptyState title="Os perfis não foram carregados" role="alert" action={<Button onClick={() => void profiles.refetch()}>Tentar novamente</Button>} />
        ) : (
          <Card className={styles.current}>
            <UserRound size={20} aria-hidden="true" />
            <strong>{profiles.data.current_profile?.name ?? "Nenhum perfil selecionado"}</strong>
            {profiles.data.current_profile ? (
              <Button size="sm" variant="secondary" loading={select.isPending} onClick={() => select.mutate(null)}>Limpar seleção</Button>
            ) : null}
          </Card>
        )}
      </section>

      <section className={styles.section} aria-labelledby="available-profiles-title">
        <h2 id="available-profiles-title" className={styles.heading}>Perfis disponíveis</h2>
        {profiles.data?.profiles.length ? (
          <ul className={styles.list}>
            {profiles.data.profiles.map((profile) => {
              const current = profile.id === profiles.data.current_profile?.id
              return (
                <li key={profile.id}>
                  <Card className={styles.row}>
                    <span>{profile.name}</span>
                    {current ? <span className={styles.selected}><Check size={15} aria-hidden="true" />Selecionado</span> : (
                      <Button size="sm" variant="secondary" loading={select.isPending && select.variables === profile.id} onClick={() => select.mutate(profile.id)}>Selecionar</Button>
                    )}
                  </Card>
                </li>
              )
            })}
          </ul>
        ) : profiles.data ? <p className={styles.empty}>Ainda não há perfis. Crie um para atribuir comentários.</p> : null}
      </section>

      <section className={styles.section} aria-labelledby="create-profile-title">
        <h2 id="create-profile-title" className={styles.heading}>Criar perfil</h2>
        <form className={styles.create} onSubmit={submit}>
          <Input label="Nome de exibição" value={name} maxLength={80} onChange={(event) => setName(event.target.value)} placeholder="Como devemos chamar você?" />
          <Button type="submit" leftIcon={<UserRoundPlus size={16} />} loading={create.isPending} disabled={!name.trim()}>Criar e selecionar</Button>
        </form>
      </section>
    </div>
  )
}
