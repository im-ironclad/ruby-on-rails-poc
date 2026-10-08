// Mirrors app/serializers/{issuer,bond,payment}_serializer.rb. Change both together.

export type IssuerType = 'city' | 'county' | 'school_district' | 'utility'

// Derived on the server from paid_on and today's date. Never stored.
export type PaymentStatus = 'paid' | 'upcoming' | 'overdue'

// ISO date string, e.g. "2026-07-01". Dates stay strings so no timezone shifts creep in.
export type IsoDate = string

// Money is always integer cents. Format only at the edge, in lib/format.ts.
export type Cents = number

export interface Issuer {
  id: number
  name: string
  issuer_type: IssuerType
  state: string
}

export interface IssuerSummary extends Issuer {
  outstanding_principal_cents: Cents
}

export interface Payment {
  id: number
  bond_id: number
  due_on: IsoDate
  principal_cents: Cents
  interest_cents: Cents
  total_cents: Cents
  paid_on: IsoDate | null
  status: PaymentStatus
}

export interface UpcomingPayment extends Payment {
  bond_series_name: string
  cusip: string
  issuer_id: number
  issuer_name: string
}

export interface Bond {
  id: number
  issuer_id: number
  series_name: string
  cusip: string
  par_amount_cents: Cents
  // Decimal fraction as a string, e.g. "0.0425". A JSON number would pass through a float.
  coupon_rate: string
  issued_on: IsoDate
  maturity_on: IsoDate
}

export interface BondWithSchedule extends Bond {
  outstanding_principal_cents: Cents
  payments: Payment[]
}

export interface IssuerDetail extends Issuer {
  bonds: BondWithSchedule[]
}

export interface Dashboard {
  window_days: number
  upcoming_payments: UpcomingPayment[]
  issuers: IssuerSummary[]
}

export interface BondInput {
  issuer_id: number
  series_name: string
  cusip: string
  par_amount_cents: Cents
  coupon_rate: string
  issued_on: IsoDate
  maturity_on: IsoDate
}
