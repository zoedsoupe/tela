import { act, renderHook } from "@testing-library/react"
import { useInView } from "./useInView"

class FakeIntersectionObserver {
  static last: FakeIntersectionObserver | null = null
  readonly options: IntersectionObserverInit
  private readonly callback: IntersectionObserverCallback

  constructor(callback: IntersectionObserverCallback, options: IntersectionObserverInit = {}) {
    this.callback = callback
    this.options = options
    FakeIntersectionObserver.last = this
  }

  observe() {}
  disconnect() {}
  unobserve() {}
  takeRecords(): IntersectionObserverEntry[] { return [] }

  intersect(entry: Partial<IntersectionObserverEntry> = {}): void {
    this.callback([{ isIntersecting: true, ...entry } as IntersectionObserverEntry], this as unknown as IntersectionObserver)
  }
}

describe('useInView', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    FakeIntersectionObserver.last = null
  })

  it('uses a valid pixel root margin and observes intersections', () => {
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver)
    const element = document.createElement('div')
    const { result } = renderHook(() => useInView(element))

    expect(FakeIntersectionObserver.last?.options.rootMargin).toBe('400px')
    act(() => FakeIntersectionObserver.last?.intersect())
    expect(result.current).toBe(true)
  })
})
