import { Alert, Button, InputAdornment, MenuItem, Paper, Stack, TextField, Typography } from '@mui/material'
import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, ApiError, type FieldErrors } from '../../api/client'
import { dollarsToCents, percentToFraction } from '../../lib/format'
import { useApi } from '../../lib/useApi'
import type { BondInput, BondWithSchedule, Issuer } from '../../types/bonds'

const EMPTY = { issuer_id: '', series_name: '', cusip: '', par_dollars: '', coupon_percent: '', issued_on: '', maturity_on: '' }

type FormValues = typeof EMPTY

// The form edits dollars and percent; the API speaks cents and fractions. Map server field names back.
const SERVER_TO_FORM_FIELD: Record<string, keyof FormValues> = {
  par_amount_cents: 'par_dollars',
  coupon_rate: 'coupon_percent',
  issuer: 'issuer_id',
}

function toFormErrors(serverErrors: FieldErrors): FieldErrors {
  const formErrors: FieldErrors = {}
  for (const [field, messages] of Object.entries(serverErrors)) {
    const name = SERVER_TO_FORM_FIELD[field] ?? field
    formErrors[name] = [...(formErrors[name] ?? []), ...messages]
  }
  return formErrors
}

export function NewBondForm() {
  const { state } = useApi<Issuer[]>('/api/issuers')
  const navigate = useNavigate()
  const [values, setValues] = useState<FormValues>(EMPTY)
  const [errors, setErrors] = useState<FieldErrors>({})
  const [submitting, setSubmitting] = useState(false)

  const field = (name: keyof FormValues) => ({
    name,
    value: values[name],
    onChange: (e: { target: { value: string } }) => setValues({ ...values, [name]: e.target.value }),
    error: (errors[name]?.length ?? 0) > 0,
    helperText: errors[name]?.join(', '),
  })

  async function submit(event: FormEvent) {
    event.preventDefault()
    const par = dollarsToCents(values.par_dollars)
    const rate = percentToFraction(values.coupon_percent)
    const clientErrors: FieldErrors = {}
    if (par === null) clientErrors.par_dollars = ['enter a dollar amount like 1,500,000.00']
    if (rate === null) clientErrors.coupon_percent = ['enter a percentage like 4.25']
    if (par === null || rate === null) return setErrors(clientErrors)

    const bond: BondInput = {
      issuer_id: Number(values.issuer_id),
      series_name: values.series_name,
      cusip: values.cusip.toUpperCase(),
      par_amount_cents: par,
      coupon_rate: rate,
      issued_on: values.issued_on,
      maturity_on: values.maturity_on,
    }

    setSubmitting(true)
    try {
      const created = await api.post<BondWithSchedule>('/api/bonds', { bond })
      navigate(`/bonds/issuers/${created.issuer_id}?bond=${created.id}`)
    } catch (e) {
      if (!(e instanceof ApiError)) throw e
      setErrors(toFormErrors(e.errors))
    } finally {
      setSubmitting(false)
    }
  }

  const baseErrors = errors.base

  return (
    <Paper variant="outlined" sx={{ p: 3, maxWidth: 640 }}>
      <Typography variant="h5" gutterBottom>
        New bond
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Saving generates a level-principal annual payment schedule.
      </Typography>
      {baseErrors && baseErrors.length > 0 && <Alert severity="error">{baseErrors.join(', ')}</Alert>}
      <Stack component="form" spacing={2} onSubmit={submit} noValidate>
        <TextField select label="Issuer" required {...field('issuer_id')}>
          {state.status === 'ready' ? (
            state.data.map((issuer) => (
              <MenuItem key={issuer.id} value={String(issuer.id)}>
                {issuer.name} ({issuer.state})
              </MenuItem>
            ))
          ) : (
            <MenuItem disabled value="">
              Loading issuers…
            </MenuItem>
          )}
        </TextField>
        <TextField label="Series name" required placeholder="General Obligation Bonds, Series 2026A" {...field('series_name')} />
        <TextField label="CUSIP" required placeholder="9 characters, e.g. 736688ZZ9" {...field('cusip')} />
        <Stack direction="row" spacing={2}>
          <TextField
            label="Par amount"
            required
            fullWidth
            slotProps={{ input: { startAdornment: <InputAdornment position="start">$</InputAdornment> } }}
            {...field('par_dollars')}
          />
          <TextField
            label="Coupon rate"
            required
            fullWidth
            slotProps={{ input: { endAdornment: <InputAdornment position="end">%</InputAdornment> } }}
            {...field('coupon_percent')}
          />
        </Stack>
        <Stack direction="row" spacing={2}>
          <TextField label="Issued on" type="date" required fullWidth slotProps={{ inputLabel: { shrink: true } }} {...field('issued_on')} />
          <TextField label="Matures on" type="date" required fullWidth slotProps={{ inputLabel: { shrink: true } }} {...field('maturity_on')} />
        </Stack>
        <Stack direction="row" spacing={2}>
          <Button type="submit" variant="contained" disabled={submitting}>
            Create bond
          </Button>
          <Button onClick={() => navigate('/bonds')}>Cancel</Button>
        </Stack>
      </Stack>
    </Paper>
  )
}
