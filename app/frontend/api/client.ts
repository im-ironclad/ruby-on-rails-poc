// The one place the frontend talks HTTP. Every API error has the shape { errors: { field: [messages] } }
// (see app/controllers/api/base_controller.rb), so callers get a typed ApiError they can render per field.

export type FieldErrors = Record<string, string[]>

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly errors: FieldErrors,
  ) {
    super(Object.entries(errors).map(([field, messages]) => `${field} ${messages.join(', ')}`).join('; '))
  }
}

// Rails puts the CSRF token in a <meta> tag (csrf_meta_tags in the layout). Same-origin requests send it back.
function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const response = await fetch(path, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken(),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })

  if (response.status === 204) return undefined as T

  const json = await response.json().catch(() => ({}))
  if (!response.ok) throw new ApiError(response.status, json.errors ?? { base: [response.statusText] })
  return json as T
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body: unknown) => request<T>('POST', path, body),
  patch: <T>(path: string, body: unknown) => request<T>('PATCH', path, body),
  delete: (path: string) => request<void>('DELETE', path),
}
