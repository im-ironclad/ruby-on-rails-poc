import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Link,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { Link as RouterLink, useParams, useSearchParams } from 'react-router-dom'
import { api } from '../../api/client'
import { Loadable } from '../../components/Loadable'
import { PaymentStatusChip } from '../../components/PaymentStatusChip'
import { formatCents, formatDate, formatRate, todayIso } from '../../lib/format'
import { useApi } from '../../lib/useApi'
import type { BondWithSchedule, IssuerDetail as IssuerDetailData, Payment } from '../../types/bonds'
import { ISSUER_TYPE_LABELS } from './BondsDashboard'

export function IssuerDetail() {
  const { id } = useParams()
  const [searchParams] = useSearchParams()
  const highlightBondId = Number(searchParams.get('bond'))
  const { state, setData } = useApi<IssuerDetailData>(`/api/issuers/${id}`)
  const [error, setError] = useState<string | null>(null)

  async function markPaid(payment: Payment) {
    setError(null)
    try {
      const updated = await api.patch<Payment>(`/api/debt_service_payments/${payment.id}`, {
        debt_service_payment: { paid_on: todayIso() },
      })
      setData((issuer) => ({ ...issuer, bonds: issuer.bonds.map((bond) => replacePayment(bond, updated)) }))
    } catch (e) {
      setError((e as Error).message)
    }
  }

  return (
    <Loadable state={state}>
      {(issuer) => (
        <Stack spacing={3}>
          <Box>
            <Link component={RouterLink} to="/bonds" underline="hover">
              ← Dashboard
            </Link>
            <Typography variant="h4">{issuer.name}</Typography>
            <Typography color="text.secondary">
              {ISSUER_TYPE_LABELS[issuer.issuer_type]} · {issuer.state} · {issuer.bonds.length} bonds
            </Typography>
          </Box>
          {error && <Alert severity="error">{error}</Alert>}
          {issuer.bonds.map((bond) => (
            <Accordion key={bond.id} defaultExpanded={bond.id === highlightBondId} variant="outlined">
              <AccordionSummary>
                <Stack direction="row" spacing={3} sx={{ flexWrap: 'wrap', alignItems: 'baseline' }}>
                  <Typography sx={{ fontWeight: 600 }}>{bond.series_name}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    CUSIP {bond.cusip} · {formatRate(bond.coupon_rate)} · matures {formatDate(bond.maturity_on)}
                  </Typography>
                  <Typography variant="body2">
                    Par {formatCents(bond.par_amount_cents)} · Outstanding {formatCents(bond.outstanding_principal_cents)}
                  </Typography>
                </Stack>
              </AccordionSummary>
              <AccordionDetails>
                <ScheduleTable payments={bond.payments} onMarkPaid={markPaid} />
              </AccordionDetails>
            </Accordion>
          ))}
        </Stack>
      )}
    </Loadable>
  )
}

function replacePayment(bond: BondWithSchedule, updated: Payment): BondWithSchedule {
  if (bond.id !== updated.bond_id) return bond
  const payments = bond.payments.map((payment) => (payment.id === updated.id ? updated : payment))
  const outstanding = payments.filter((p) => p.status !== 'paid').reduce((sum, p) => sum + p.principal_cents, 0)
  return { ...bond, payments, outstanding_principal_cents: outstanding }
}

function ScheduleTable({ payments, onMarkPaid }: { payments: Payment[]; onMarkPaid: (payment: Payment) => void }) {
  return (
    <Table size="small" aria-label="payment schedule">
      <TableHead>
        <TableRow>
          <TableCell>Due</TableCell>
          <TableCell align="right">Principal</TableCell>
          <TableCell align="right">Interest</TableCell>
          <TableCell align="right">Total</TableCell>
          <TableCell>Status</TableCell>
          <TableCell />
        </TableRow>
      </TableHead>
      <TableBody>
        {payments.map((payment) => (
          <TableRow key={payment.id}>
            <TableCell>{formatDate(payment.due_on)}</TableCell>
            <TableCell align="right">{formatCents(payment.principal_cents)}</TableCell>
            <TableCell align="right">{formatCents(payment.interest_cents)}</TableCell>
            <TableCell align="right">{formatCents(payment.total_cents)}</TableCell>
            <TableCell>
              <PaymentStatusChip status={payment.status} />
              {payment.paid_on && (
                <Typography variant="caption" color="text.secondary" sx={{ ml: 1 }}>
                  {formatDate(payment.paid_on)}
                </Typography>
              )}
            </TableCell>
            <TableCell align="right">
              {payment.status !== 'paid' && (
                <Button size="small" onClick={() => onMarkPaid(payment)}>
                  Mark paid
                </Button>
              )}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
