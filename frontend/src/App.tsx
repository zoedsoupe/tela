import { lazy, Suspense } from "react"
import { Navigate, Route, Routes } from "react-router-dom"
import { AppProviders } from "@/app/AppProviders"
import { ErrorBoundary } from "@/app/ErrorBoundary"
import DashboardLayout from "@/features/dashboard/DashboardLayout"
import BrandPage from "@/pages/dashboard/BrandPage"
import DashboardTemplatesPage from "@/pages/dashboard/TemplatesPage"
import DesignsPage from "@/pages/dashboard/DesignsPage"
import HomePage from "@/pages/dashboard/HomePage"
import TrashPage from "@/pages/dashboard/TrashPage"
import UploadsPage from "@/pages/dashboard/UploadsPage"
import CreatePage from "@/pages/CreatePage"
import NotFoundPage from "@/pages/NotFoundPage"
import ProfileSettingsPage from "@/pages/ProfileSettingsPage"
import TemplateDetailPage from "@/pages/TemplateDetailPage"

const Harness = lazy(() => import("@/editor/dev/HarnessApp").then((module) => ({ default: module.Harness })))
const WorkspaceEditor = lazy(() => import("@/editor/routes/EditorRoutes").then((module) => ({ default: module.WorkspaceEditor })))
const LocalEditor = lazy(() => import("@/editor/routes/EditorRoutes").then((module) => ({ default: module.LocalEditor })))
const SharedEditor = lazy(() => import("@/editor/routes/EditorRoutes").then((module) => ({ default: module.SharedEditor })))

function DashboardRoutes() {
  return (
    <Routes>
      <Route element={<DashboardLayout />}>
        <Route index element={<DesignsPage />} />
        <Route path="inicio" element={<HomePage />} />
        <Route path="projetos" element={<DesignsPage />} />
        <Route path="pastas/:folderId" element={<DesignsPage />} />
        <Route path="favoritos" element={<DesignsPage starred />} />
        <Route path="lixeira" element={<TrashPage />} />
        <Route path="uploads" element={<UploadsPage />} />
        <Route path="marca" element={<BrandPage />} />
        <Route path="templates" element={<DashboardTemplatesPage />} />
        <Route path="templates/:slug" element={<TemplateDetailPage />} />
        <Route path="configuracoes" element={<ProfileSettingsPage />} />
        <Route path="criar" element={<CreatePage />} />
        <Route path="create" element={<CreatePage />} />
        <Route path="modelos" element={<DashboardTemplatesPage />} />
        <Route path="modelos/:slug" element={<TemplateDetailPage />} />
        <Route path="painel" element={<Navigate to="/" replace />} />
        <Route path="painel/projetos" element={<DesignsPage />} />
        <Route path="painel/com estrela" element={<DesignsPage starred />} />
        <Route path="painel/designs/pasta/:folderId" element={<DesignsPage />} />
        <Route path="painel/lixeira" element={<TrashPage />} />
        <Route path="painel/carregamentos" element={<UploadsPage />} />
        <Route path="painel/marca" element={<BrandPage />} />
        <Route path="painel/modelos" element={<DashboardTemplatesPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  )
}

export default function App() {
  return (
    <AppProviders>
      <ErrorBoundary>
        <Suspense fallback={null}>
          <Routes>
            <Route path="/design/:id" element={<WorkspaceEditor />} />
            <Route path="/local/:id" element={<LocalEditor />} />
            <Route path="/s/:token" element={<SharedEditor />} />
            <Route path="/harness" element={<Harness />} />
            <Route path="/*" element={<DashboardRoutes />} />
          </Routes>
        </Suspense>
      </ErrorBoundary>
    </AppProviders>
  )
}
