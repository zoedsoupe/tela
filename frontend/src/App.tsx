import { ErrorBoundary } from "@/app/ErrorBoundary"
import { Harness } from "@/editor/dev/HarnessApp"

export default function App() {
  return (
    <ErrorBoundary>
      <Harness />
    </ErrorBoundary>
  )
}
