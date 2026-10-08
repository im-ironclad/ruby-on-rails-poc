import type { Cents, IsoDate } from '../types/bonds'

const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

export const formatCents = (cents: Cents) => usd.format(cents / 100)

export const formatRate = (fraction: string) => `${(Number(fraction) * 100).toFixed(3)}%`

export const formatDate = (iso: IsoDate) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })

export function todayIso(): IsoDate {
  const now = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
}

// "1,250,000.50" -> 125000050. String math, no floats: 0.1 + 0.2 never touches money.
export function dollarsToCents(input: string): Cents | null {
  const match = input.replaceAll(',', '').trim().match(/^(\d+)(?:\.(\d{1,2}))?$/)
  if (!match) return null
  return Number(match[1]) * 100 + Number((match[2] ?? '').padEnd(2, '0'))
}

// "4.25" (percent) -> "0.04250" (fraction string, as the API expects).
export function percentToFraction(input: string): string | null {
  const value = Number(input)
  if (input.trim() === '' || Number.isNaN(value)) return null
  return (value / 100).toFixed(5)
}
