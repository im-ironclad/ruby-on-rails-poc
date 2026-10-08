import { Chip } from '@mui/material'
import type { PaymentStatus } from '../types/bonds'

const COLORS: Record<PaymentStatus, 'success' | 'info' | 'error'> = {
  paid: 'success',
  upcoming: 'info',
  overdue: 'error',
}

export function PaymentStatusChip({ status }: { status: PaymentStatus }) {
  return <Chip size="small" label={status} color={COLORS[status]} variant={status === 'paid' ? 'outlined' : 'filled'} />
}
