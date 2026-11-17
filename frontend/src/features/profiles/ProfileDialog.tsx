import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Check, UserRound, UserRoundPlus } from "lucide-react"
import { useState, type FormEvent } from "react"
import { profilesApi, type Profile, type ProfilesResponse } from "@/lib/api"
import { Button, Card, Dialog, EmptyState, Input, Skeleton, useToast } from "@/ui"
import styles from "./ProfileDialog.module.css"

const PROFILES_KEY = ['profiles'] as const

export interface ProfileDialogProps {
  open: boolean
  onClose(): void
}

export function ProfileDialog({ open, onClose }: ProfileDialogProps) {
  const client = useQueryClient()
  const { toast } = useToast()
  const [name, setName] = useState('')
  const profiles = useQuery({
    queryKey: PROFILES_KEY,
    queryFn: ({ signal }) => profilesApi.list(signal),
    enabled: open,
  })

  const updateCache = (currentProfile: Profile | null, created?: Profile): void => {
    client.setQueryData<ProfilesResponse>(PROFILES_KEY, (current) => current
      ? {
          profiles: created && !current.profiles.some((profile) => profile.id === created.id)
            ? [...current.profiles, created]
            : current.profiles,
          current_profile: currentProfile,
        }
      : current)
  }

  const select = useMutation({
    mutationFn: async (id: string | null) => {
      if (id) return profilesApi.select(id)
      await profilesApi.clear()
      return null
    },
    onSuccess: async (currentProfile) => {
      updateCache(currentProfile)
      await client.invalidateQueries({ queryKey: PROFILES_KEY })
    },
    onError: () => toast({ title: "Não foi possível selecionar o perfil", variant: 'error' }),
  })

  const create = useMutation({
    mutationFn: async (value: string) => {
      const profile = await profilesApi.create(value)
      const currentProfile = await profilesApi.select(profile.id)
      return { profile, currentProfile }
    },
    onSuccess: async ({ profile, currentProfile }) => {
      updateCache(currentProfile, profile)
      setName('')
      await client.invalidateQueries({ queryKey: PROFILES_KEY })
      toast({ title: "Perfil criado", description: profile.name, variant: 'success' })
    },
    onError: () => toast({ title: "Não foi possível criar o perfil", description: "Confira o nome e tente novamente.", variant: 'error' }),
  })

  function submit(event: FormEvent) {
    event.preventDefault()
    const value = name.trim()
    if (value) create.mutate(value)
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Perfis"
      description="Perfis identificam quem está usando esta instância. Eles não são contas e não controlam o acesso aos designs."
      size="md"
    >
      {profiles.isPending ? <Skeleton height={180} radius="var(--raio-lg)" aria-busy="true" aria-label="Carregando perfis" /> : profiles.isError ? (
        <EmptyState
          title="Os perfis não foram carregados"
          role="alert"
          action={<Button onClick={() => void profiles.refetch()}>Tentar novamente</Button>}
        />
      ) : (
        <div className={styles.content}>
          <section className={styles.section} aria-labelledby="profile-current-title">
            <h3 id="profile-current-title" className={styles.heading}>Perfil selecionado</h3>
            <Card className={styles.current}>
              <UserRound size={20} aria-hidden="true" />
              <strong>{profiles.data.current_profile?.name ?? "Nenhum perfil selecionado"}</strong>
              {profiles.data.current_profile ? (
                <Button
                  size="sm"
                  variant="secondary"
                  loading={select.isPending && select.variables === null}
                  disabled={select.isPending || create.isPending}
                  onClick={() => select.mutate(null)}
                >
                  Limpar seleção
                </Button>
              ) : null}
            </Card>
          </section>

          <section className={styles.section} aria-labelledby="profile-available-title">
            <h3 id="profile-available-title" className={styles.heading}>Perfis disponíveis</h3>
            {profiles.data.profiles.length ? (
              <ul className={styles.list}>
                {profiles.data.profiles.map((profile) => {
                  const current = profile.id === profiles.data.current_profile?.id
                  return (
                    <li key={profile.id}>
                      <Card className={styles.row}>
                        <span className={styles.name}>{profile.name}</span>
                        {current ? (
                          <span className={styles.selected}><Check size={15} aria-hidden="true" />Selecionado</span>
                        ) : (
                          <Button
                            size="sm"
                            variant="secondary"
                            loading={select.isPending && select.variables === profile.id}
                            disabled={select.isPending || create.isPending}
                            onClick={() => select.mutate(profile.id)}
                          >
                            Selecionar
                          </Button>
                        )}
                      </Card>
                    </li>
                  )
                })}
              </ul>
            ) : <p className={styles.empty}>Ainda não há perfis. Crie um para atribuir comentários.</p>}
          </section>

          <section className={styles.section} aria-labelledby="profile-create-title">
            <h3 id="profile-create-title" className={styles.heading}>Criar perfil</h3>
            <form className={styles.create} onSubmit={submit}>
              <Input
                label="Nome de exibição"
                value={name}
                maxLength={80}
                onChange={(event) => setName(event.target.value)}
                placeholder="Como devemos chamar você?"
              />
              <Button
                type="submit"
                leftIcon={<UserRoundPlus size={16} />}
                loading={create.isPending}
                disabled={!name.trim() || select.isPending}
              >
                Criar e selecionar
              </Button>
            </form>
          </section>
        </div>
      )}
    </Dialog>
  )
}
