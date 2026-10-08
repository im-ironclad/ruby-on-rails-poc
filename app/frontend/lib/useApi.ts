import { useCallback, useEffect, useState } from 'react'
import { api } from '../api/client'

type State<T> = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; data: T }

// Fetches on mount and whenever the path changes. `setData` lets a page apply a mutation's response locally.
export function useApi<T>(path: string) {
  const [state, setState] = useState<State<T>>({ status: 'loading' })

  const reload = useCallback(() => {
    let cancelled = false
    api
      .get<T>(path)
      .then((data) => !cancelled && setState({ status: 'ready', data }))
      .catch((error: Error) => !cancelled && setState({ status: 'error', message: error.message }))
    return () => {
      cancelled = true
    }
  }, [path])

  useEffect(reload, [reload])

  const setData = useCallback((update: (data: T) => T) => {
    setState((current) => (current.status === 'ready' ? { status: 'ready', data: update(current.data) } : current))
  }, [])

  return { state, reload, setData }
}
