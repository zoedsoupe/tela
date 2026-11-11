import type { ViewHook } from 'phoenix_live_view'
import { EditorEngine } from '../editor/engine/editor'

type FabricCanvasHook = ViewHook<HTMLCanvasElement> & {
  editor?: EditorEngine
  commandListeners?: Array<{ ref: ReturnType<ViewHook['handleEvent']> }>
}

export const FabricCanvas = {
  mounted(this: FabricCanvasHook) {
    this.editor = new EditorEngine(this.el, (event, payload, callback) => {
      if (callback) this.pushEvent(event, payload, callback)
      else void this.pushEvent(event, payload)
    })

    this.commandListeners = [
      {
        ref: this.handleEvent('canvas:init', (data) => {
          void this.editor?.initialize(data.document, Number(data.revision), data.activePageId)
        }),
      },
      { ref: this.handleEvent('canvas:add_element', (data) => this.editor?.handleAddElement(data)) },
      { ref: this.handleEvent('canvas:update_active', (data) => this.editor?.handleUpdateActive(data)) },
      { ref: this.handleEvent('canvas:layer_action', (data) => this.editor?.handleLayerAction(data)) },
      { ref: this.handleEvent('canvas:page_action', (data) => this.editor?.handlePageAction(data)) },
      { ref: this.handleEvent('canvas:history_action', (data) => this.editor?.handleHistoryAction(data)) },
      { ref: this.handleEvent('canvas:export', (data) => void this.editor?.handleExport(data)) },
    ]

    void this.pushEvent('editor:ready', {})
  },

  destroyed(this: FabricCanvasHook) {
    for (const listener of this.commandListeners ?? []) this.removeHandleEvent(listener.ref)
    this.editor?.dispose()
    this.editor = undefined
  },
}
