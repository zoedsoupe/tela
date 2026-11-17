export class RevisionConflictError extends Error {
  readonly currentRevision: number | null

  constructor(currentRevision: number | null = null) {
    super('Este design foi alterado em outra edição. Recarregue para ver a versão mais recente.')
    this.name = 'RevisionConflictError'
    this.currentRevision = currentRevision
  }
}

export class ReadOnlyDesignError extends Error {
  constructor() {
    super('Este design não permite alterações.')
    this.name = 'ReadOnlyDesignError'
  }
}
