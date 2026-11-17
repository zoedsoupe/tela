
import { Folder, FolderClosed, Home, LayoutTemplate, Palette, Search, Star, Trash2, Upload } from 'lucide-react'
import { Suspense, useState, type FormEvent } from 'react'
import { Link, NavLink, Outlet, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { useQuery } from "@tanstack/react-query"
import { profilesApi } from "@/lib/api"
import { useFolders } from "@/lib/api/hooks"
import { EditorCredit } from "@/editor/EditorCredit"
import { CreateMenu } from "./CreateMenu"
import { ProfileButton } from "@/features/profiles/ProfileButton"
import { ProfileDialog } from "@/features/profiles/ProfileDialog"
import { usePageMeta } from "@/lib/usePageMeta"
import { Input, Logo } from "@/ui"
import styles from "./DashboardLayout.module.css"

type NavItem = { to: string; label: string; icon: typeof Home; end: boolean }

const MAIN: NavItem[] = [
  { to: "/inicio", label: "Página inicial", icon: Home, end: true },
  { to: "/projetos", label: "Projetos", icon: Folder, end: false },
  { to: "/favoritos", label: "Favoritos", icon: Star, end: false },
  { to: "/templates", label: "Modelos", icon: LayoutTemplate, end: false },
]
const LIBRARY: NavItem[] = [
  { to: "/marca", label: "Marca", icon: Palette, end: false },
  { to: "/uploads", label: "Envios", icon: Upload, end: false },
]
const FOOT: NavItem[] = [
  { to: "/lixeira", label: "Lixeira", icon: Trash2, end: false },
]
/** The tab bar on small screens has room for the main places only. */
const TABS: NavItem[] = [...MAIN, ...LIBRARY, ...FOOT]
const SIDEBAR_FOLDERS = 8

function NavLinks({ items }: { items: NavItem[] }) {
  return (
    <>
      {items.map(({ to, label, icon: Icon, end }) => (
        <NavLink key={to} to={to} end={end} className={styles.link}>
          <Icon size={18} aria-hidden="true" />
          <span>{label}</span>
        </NavLink>
      ))}
    </>
  )
}

/** The top-level folders, so a folder is one click away from anywhere in the dashboard. */
function SidebarFolders() {
  const folders = useFolders()
  const top = (folders.data ?? []).filter((folder) => folder.parent === null).sort((a, b) => a.name.localeCompare(b.name))
  if (top.length === 0) return null
  return (
    <div className={styles.group}>
      <p className={styles.groupLabel}>{"Pastas"}</p>
      {top.slice(0, SIDEBAR_FOLDERS).map((folder) => (
        <NavLink key={folder.id} to={`/pastas/${folder.id}`} className={`${styles.link} ${styles.folder}`}>
          <FolderClosed size={16} aria-hidden="true" />
          <span className={styles.folderName}>{folder.name}</span>
          <span className={styles.count}>{folder.design_count}</span>
        </NavLink>
      ))}
      {top.length > SIDEBAR_FOLDERS ? (
        <Link to="/painel/projetos" className={styles.allFolders}>
          {"Todas as "}{top.length} {"pastas"}</Link>
      ) : null}
    </div>
  )
}

/** Global design search; the field mirrors the `q` shown on the designs page. */
function DashboardSearch({ initial }: { initial: string }) {
  const navigate = useNavigate()
  const [search, setSearch] = useState(initial)

  function submitSearch(event: FormEvent) {
    event.preventDefault()
    const q = search.trim()
    navigate(q ? `/projetos?q=${encodeURIComponent(q)}` : "/projetos")
  }

  return (
    <form role="search" className={styles.search} onSubmit={submitSearch}>
      <Input label={"Pesquise seus designs"} hideLabel type="search" placeholder={"Pesquisar designs"} leftIcon={<Search size={16} />} value={search} onChange={(event) => setSearch(event.target.value)} />
    </form>
  )
}

/** Dashboard chrome: sidebar (tab bar on small screens), search and create menu. */
export default function DashboardLayout() {
  usePageMeta({ noindex: true })
  const location = useLocation()
  const [params] = useSearchParams()
  const searchValue = location.pathname.startsWith("/projetos") ? (params.get('q') ?? '') : ''
  const profile = useQuery({ queryKey: ['profiles'], queryFn: ({ signal }) => profilesApi.list(signal) })
  const [profileDialogOpen, setProfileDialogOpen] = useState(false)

  return (
    <div className={styles.shell}>
      <aside className={styles.sidebar}>
        <Link to="/" className={styles.logo} aria-label="Biblioteca do Tela">
          <Logo height={30} />
        </Link>
        <nav aria-label={"Painel"} className={styles.nav}>
          <div className={styles.group}>
            <NavLinks items={MAIN} />
          </div>
          <div className={styles.group}>
            <p className={styles.groupLabel}>{"Biblioteca"}</p>
            <NavLinks items={LIBRARY} />
          </div>
          <SidebarFolders />
          <div className={`${styles.group} ${styles.foot}`}>
            <NavLinks items={FOOT} />
          </div>
        </nav>
      </aside>
      <div className={styles.column}>
        <header className={styles.topbar}>
          <Link to="/" className={styles.mobileLogo} aria-label="Biblioteca do Tela">
            <Logo variant="mark" height={30} />
          </Link>
          <DashboardSearch key={searchValue} initial={searchValue} />
          <div className={styles.actions}>
            <ProfileButton profile={profile.data?.current_profile} onClick={() => setProfileDialogOpen(true)} />
            <CreateMenu />
          </div>
        </header>
        <nav aria-label={"Seções do painel"} className={styles.tabs}>
          {TABS.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} className={styles.tab}>
              <Icon size={16} aria-hidden="true" />
              {label}
            </NavLink>
          ))}
        </nav>
        <main id="main" tabIndex={-1} className={styles.main}>
          <Suspense fallback={null}>
            <Outlet />
          </Suspense>
        </main>
        <EditorCredit />
      </div>
      <ProfileDialog open={profileDialogOpen} onClose={() => setProfileDialogOpen(false)} />
    </div>
  )
}
