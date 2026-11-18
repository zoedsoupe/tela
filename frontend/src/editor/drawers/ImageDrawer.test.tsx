import { act, fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { StockAssetsService } from '@/types/adapter'
import type { Asset, StockPage, StockPhoto, StockProviderError } from '@/types/api'
import { setupEditor } from '../animation/testing'
import { EditorProvider } from '../EditorProvider'
import type { EditorEngine } from '../engine/editor'
import { t } from '../strings'
import { ImageDrawer } from './ImageDrawer'

const asset: Asset = {
  id: 'asset-local',
  kind: 'image',
  name: 'beach.jpg',
  url: '/media/beach.jpg',
  thumb_url: '/media/beach-thumb.jpg',
  width: 1600,
  height: 900,
  size: 1,
  mime: 'image/jpeg',
  tags: [],
  attribution: null,
  created_at: '',
}

function photo(overrides: Partial<StockPhoto> = {}): StockPhoto {
  return {
    external_id: 'photo-1',
    provider: 'pixabay',
    thumb_url: 'https://images.example.test/thumb.jpg',
    full_url: 'https://images.example.test/full.jpg',
    author: 'Ada',
    ...overrides,
  }
}

function stockPage(
  results: StockPhoto[] = [photo()],
  nextPage: number | null = null,
  errors: StockProviderError[] = [],
): StockPage {
  return {
    count: results.length,
    next: nextPage === null ? null : String(nextPage),
    previous: null,
    results,
    errors,
  }
}

function makeStockService(search?: StockAssetsService['search']): StockAssetsService {
  return {
    search: search ?? vi.fn(async () => stockPage()),
    import: vi.fn(async () => asset),
  }
}

function provideStock(engine: EditorEngine, stock: StockAssetsService): void {
  engine.adapter = {
    ...engine.adapter,
    services: {
      ...engine.adapter.services,
      assets: { ...engine.adapter.services.assets, stock },
    },
  }
}

async function renderDrawer(engine: EditorEngine, close = vi.fn()): Promise<() => void> {
  await act(async () => {
    render(<EditorProvider engine={engine} portalRoot={document.body}><ImageDrawer close={close} /></EditorProvider>)
  })
  return close
}

describe('ImageDrawer', () => {
  let engine: EditorEngine | null = null

  afterEach(() => {
    engine?.dispose()
    engine = null
    vi.useRealTimers()
    document.body.innerHTML = ''
  })

  it('keeps local uploads and image-grid layouts available without stock service', async () => {
    const setup = await setupEditor()
    engine = setup.engine
    const insert = vi.spyOn(setup.engine.imageGrids, 'insert').mockResolvedValue()
    const close = vi.fn()
    await renderDrawer(setup.engine, close)

    expect(screen.getByTestId('image-tab-uploads')).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByTestId('image-tab-grids')).toBeVisible()
    expect(screen.queryByTestId('image-tab-stock')).toBeNull()
    await userEvent.click(screen.getByTestId('image-tab-grids'))
    expect(screen.getByRole('tabpanel', { name: t.imageDrawer.grids })).toBeVisible()
    await userEvent.click(await screen.findByTestId('grid-preset-two-columns'))
    expect(insert).toHaveBeenCalledWith('two-columns')
    expect(close).toHaveBeenCalledOnce()
  })

  it('shows the stock tab only when the adapter supplies the stock service', async () => {
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, makeStockService())
    await renderDrawer(setup.engine)

    expect(screen.getByTestId('image-tab-uploads')).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByTestId('image-tab-stock')).toBeVisible()
    await act(async () => {
      fireEvent.click(screen.getByTestId('image-tab-stock'))
    })
    expect(screen.getByRole('tabpanel', { name: t.imageDrawer.stock })).toBeVisible()
    expect(screen.getByTestId('stock-search')).toBeVisible()
  })

  it('debounces search, filters providers, and follows backend pagination', async () => {
    vi.useFakeTimers()
    const search = vi.fn(async ({ provider, page }: { q: string; provider: 'all' | 'pixabay' | 'wikimedia' | 'pexels' | 'unsplash'; page: number }) =>
      stockPage([photo({ external_id: `${provider}-${page}`, provider: provider === 'all' ? 'pixabay' : provider })], page === 1 ? 3 : null))
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, makeStockService(search))
    await renderDrawer(setup.engine)
    fireEvent.click(screen.getByTestId('image-tab-stock'))
    const input = screen.getByTestId('stock-search')

    fireEvent.change(input, { target: { value: '  ' } })
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300)
    })
    fireEvent.change(input, { target: { value: 'b' } })
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300)
    })
    expect(search).not.toHaveBeenCalled()

    fireEvent.change(input, { target: { value: 'beach' } })
    await act(async () => {
      await vi.advanceTimersByTimeAsync(299)
    })
    expect(search).not.toHaveBeenCalled()
    await act(async () => {
      await vi.advanceTimersByTimeAsync(1)
    })
    expect(search).toHaveBeenCalledWith({ q: 'beach', provider: 'all', page: 1 })

    fireEvent.click(screen.getByTestId('stock-provider-pexels'))
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300)
    })
    expect(search).toHaveBeenLastCalledWith({ q: 'beach', provider: 'pexels', page: 1 })

    fireEvent.click(screen.getByRole('button', { name: t.imageDrawer.loadMore }))
    await act(async () => {
      await Promise.resolve()
    })
    expect(search).toHaveBeenLastCalledWith({ q: 'beach', provider: 'pexels', page: 3 })
    expect(screen.getByTestId('stock-photo-pexels-3')).toBeVisible()
  })

  it('imports the stock photo asset, inserts it, and closes the drawer', async () => {
    const unsplash = photo({
      provider: 'unsplash',
      external_id: 'unsplash-1',
      author_url: 'https://unsplash.com/@ada?utm_source=tela&utm_medium=referral',
      source_url: 'https://unsplash.com/?utm_source=tela&utm_medium=referral',
    })
    const stock = makeStockService(vi.fn(async () => stockPage([unsplash])))
    const pendingImport: Array<(imported: Asset) => void> = []
    stock.import = vi.fn(() => new Promise<Asset>((resolve) => pendingImport.push(resolve)))
    const close = vi.fn()
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, stock)
    const insert = vi.spyOn(setup.engine.insert, 'imageFromAsset').mockResolvedValue()
    await renderDrawer(setup.engine, close)
    fireEvent.click(screen.getByTestId('image-tab-stock'))
    fireEvent.change(screen.getByTestId('stock-search'), { target: { value: 'beach' } })
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 320))
    })

    expect(screen.getByText(t.imageDrawer.unsplashPhotoBy)).toBeVisible()
    expect(screen.getByRole('link', { name: 'Ada' })).toHaveAttribute('href', unsplash.author_url)
    expect(screen.getByRole('link', { name: 'Unsplash' })).toHaveAttribute('href', unsplash.source_url)
    fireEvent.click(screen.getByTestId('stock-photo-unsplash-1'))
    expect(screen.getByTestId('stock-photo-unsplash-1')).toBeDisabled()
    await act(async () => {
      pendingImport[0]?.(asset)
      await Promise.resolve()
      await Promise.resolve()
    })

    expect(stock.import).toHaveBeenCalledWith('unsplash', 'unsplash-1')
    expect(insert).toHaveBeenCalledWith({
      id: asset.id,
      url: asset.url,
      thumbUrl: asset.thumb_url,
      width: asset.width,
      height: asset.height,
      name: asset.name,
      kind: asset.kind,
    })
    expect(close).toHaveBeenCalledOnce()
  })

  it('shows an import failure and allows retry', async () => {
    const stock = makeStockService()
    vi.mocked(stock.import)
      .mockRejectedValueOnce(new Error('temporarily unavailable'))
      .mockResolvedValueOnce(asset)
    const close = vi.fn()
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, stock)
    const insert = vi.spyOn(setup.engine.insert, 'imageFromAsset').mockResolvedValue()
    await renderDrawer(setup.engine, close)
    fireEvent.click(screen.getByTestId('image-tab-stock'))
    fireEvent.change(screen.getByTestId('stock-search'), { target: { value: 'beach' } })
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 320))
    })

    fireEvent.click(screen.getByTestId('stock-photo-photo-1'))
    expect(await screen.findByRole('alert')).toHaveTextContent(t.imageDrawer.importFailed)
    expect(screen.getByTestId('stock-photo-photo-1')).toBeEnabled()
    fireEvent.click(screen.getByTestId('stock-photo-photo-1'))
    await act(async () => {
      await Promise.resolve()
    })

    expect(stock.import).toHaveBeenCalledTimes(2)
    expect(insert).toHaveBeenCalledOnce()
    expect(close).toHaveBeenCalledOnce()
  })

  it('shows empty, search failure, and partial-provider error states', async () => {
    const search = vi.fn()
      .mockResolvedValueOnce(stockPage([]))
      .mockRejectedValueOnce(new Error('offline'))
      .mockResolvedValueOnce(stockPage([photo()], null, [{ provider: 'unsplash', code: 'timeout' }]))
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, makeStockService(search))
    await renderDrawer(setup.engine)
    fireEvent.click(screen.getByTestId('image-tab-stock'))
    const input = screen.getByTestId('stock-search')

    fireEvent.change(input, { target: { value: 'empty' } })
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 320))
    })
    expect(screen.getByText(t.imageDrawer.stockEmpty)).toBeVisible()

    fireEvent.change(input, { target: { value: 'offline' } })
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 320))
    })
    expect(screen.getByRole('alert')).toHaveTextContent(t.imageDrawer.stockFailed)

    fireEvent.change(input, { target: { value: 'partial' } })
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 320))
    })
    expect(screen.getByTestId('stock-photo-photo-1')).toBeVisible()
    expect(screen.getByRole('status')).toHaveTextContent(t.imageDrawer.stockPartial('Unsplash não respondeu a tempo'))
  })

  it('ignores stale search results after the query changes', async () => {
    vi.useFakeTimers()
    const pending = new Map<string, (result: StockPage) => void>()
    const search = vi.fn(({ q }: { q: string }) => new Promise<StockPage>((resolve) => pending.set(q, resolve)))
    const setup = await setupEditor()
    engine = setup.engine
    provideStock(setup.engine, makeStockService(search))
    await renderDrawer(setup.engine)
    fireEvent.click(screen.getByTestId('image-tab-stock'))
    const input = screen.getByTestId('stock-search')

    fireEvent.change(input, { target: { value: 'beach' } })
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300)
    })
    fireEvent.change(input, { target: { value: 'forest' } })
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300)
    })
    await act(async () => {
      pending.get('forest')?.(stockPage([photo({ external_id: 'forest-result' })]))
      await Promise.resolve()
    })
    await act(async () => {
      pending.get('beach')?.(stockPage([photo({ external_id: 'stale-result' })]))
      await Promise.resolve()
    })

    expect(screen.getByTestId('stock-photo-forest-result')).toBeVisible()
    expect(screen.queryByTestId('stock-photo-stale-result')).toBeNull()
  })
})
