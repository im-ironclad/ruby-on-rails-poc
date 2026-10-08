import {
  Button,
  Card,
  CardActionArea,
  CardContent,
  Grid,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import { Loadable } from '../../components/Loadable'
import { PaymentStatusChip } from '../../components/PaymentStatusChip'
import { formatCents, formatDate } from '../../lib/format'
import { useApi } from '../../lib/useApi'
import type { Dashboard, IssuerType } from '../../types/bonds'

const WINDOWS = [30, 90, 365] as const

export const ISSUER_TYPE_LABELS: Record<IssuerType, string> = {
  city: 'City',
  county: 'County',
  school_district: 'School district',
  utility: 'Utility',
}

export function BondsDashboard() {
  const [days, setDays] = useState<number>(90)
  const { state } = useApi<Dashboard>(`/api/dashboard?days=${days}`)

  return (
    <Stack spacing={4}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4">Debt portfolio</Typography>
        <Button variant="contained" component={RouterLink} to="/bonds/new">
          New bond
        </Button>
      </Stack>

      <Loadable state={state}>
        {(dashboard) => (
          <>
            <section>
              <Typography variant="h6" gutterBottom>
                Outstanding principal by issuer
              </Typography>
              <Grid container spacing={2}>
                {dashboard.issuers.map((issuer) => (
                  <Grid key={issuer.id} size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card variant="outlined">
                      <CardActionArea component={RouterLink} to={`/bonds/issuers/${issuer.id}`}>
                        <CardContent>
                          <Typography variant="overline" color="text.secondary">
                            {ISSUER_TYPE_LABELS[issuer.issuer_type]} · {issuer.state}
                          </Typography>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                            {issuer.name}
                          </Typography>
                          <Typography variant="h5">{formatCents(issuer.outstanding_principal_cents)}</Typography>
                        </CardContent>
                      </CardActionArea>
                    </Card>
                  </Grid>
                ))}
              </Grid>
            </section>

            <section>
              <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                <Typography variant="h6">Payments due in the next {dashboard.window_days} days</Typography>
                <ToggleButtonGroup size="small" exclusive value={days} onChange={(_, value) => value && setDays(value)}>
                  {WINDOWS.map((window) => (
                    <ToggleButton key={window} value={window}>
                      {window}d
                    </ToggleButton>
                  ))}
                </ToggleButtonGroup>
              </Stack>
              <Paper variant="outlined">
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Due</TableCell>
                      <TableCell>Issuer</TableCell>
                      <TableCell>Bond</TableCell>
                      <TableCell align="right">Principal</TableCell>
                      <TableCell align="right">Interest</TableCell>
                      <TableCell align="right">Total</TableCell>
                      <TableCell>Status</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {dashboard.upcoming_payments.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={7}>Nothing due in this window.</TableCell>
                      </TableRow>
                    )}
                    {dashboard.upcoming_payments.map((payment) => (
                      <TableRow key={payment.id}>
                        <TableCell>{formatDate(payment.due_on)}</TableCell>
                        <TableCell>
                          <RouterLink to={`/bonds/issuers/${payment.issuer_id}`}>{payment.issuer_name}</RouterLink>
                        </TableCell>
                        <TableCell>
                          {payment.bond_series_name}
                          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                            CUSIP {payment.cusip}
                          </Typography>
                        </TableCell>
                        <TableCell align="right">{formatCents(payment.principal_cents)}</TableCell>
                        <TableCell align="right">{formatCents(payment.interest_cents)}</TableCell>
                        <TableCell align="right">{formatCents(payment.total_cents)}</TableCell>
                        <TableCell>
                          <PaymentStatusChip status={payment.status} />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Paper>
            </section>
          </>
        )}
      </Loadable>
    </Stack>
  )
}
