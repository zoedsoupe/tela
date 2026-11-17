import type { Profile } from "@/lib/api"
import { Avatar, Button } from "@/ui"
import styles from "./ProfileButton.module.css"

export function ProfileButton({ profile, onClick }: { profile: Profile | null | undefined; onClick(): void }) {
  const name = profile?.name ?? "Selecionar perfil"
  return (
    <Button
      className={styles.button}
      variant="ghost"
      size="sm"
      aria-label={profile ? `Perfil atual: ${profile.name}` : "Selecionar perfil"}
      onClick={onClick}
      data-testid="profile-open"
    >
      <Avatar name={name} size={28} />
      <span className={styles.name}>{profile?.name ?? "Perfil"}</span>
    </Button>
  )
}
