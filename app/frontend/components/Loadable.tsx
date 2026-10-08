import { Alert, CircularProgress, Stack } from '@mui/material'
import type { ReactNode } from 'react'
import type { useApi } from '../lib/useApi'

type ApiState<T> = ReturnType<typeof useApi<T>>['state']

export function Loadable<T>({ state, children }: { state: ApiState<T>; children: (data: T) => ReactNode }) {
  if (state.status === 'loading') {
    return (
      <Stack sx={{ alignItems: 'center', py: 6 }}>
        <CircularProgress />
      </Stack>
    )
  }
  if (state.status === 'error') return <Alert severity="error">{state.message}</Alert>
  return <>{children(state.data)}</>
}
