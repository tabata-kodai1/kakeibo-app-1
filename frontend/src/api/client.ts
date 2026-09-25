// API 呼び出しの共通部分（docs/tech-stack.md「HTTPクライアント: 標準の fetch」）。
// axios は入れず、次の 3 つの責務だけをここで引き受ける。
//   - タイムアウトの付与（N-26）。fetch は既定でタイムアウトを持たず、応答がないと画面がローディングのまま止まる
//   - エラーレスポンス（400 / 404 / 500）の解釈。項目エラーは errors を呼び出し元に返す
//   - JSON のパースと型付け

// 一定時間で打ち切る（docs/screens.md「エラーの表示」）
const TIMEOUT_MS = 10_000

// 未指定なら相対パス（開発時は Vite の proxy を通る）。本番は S3 と EC2 でオリジンが分かれるため、
// EC2 の API の URL をビルド時に指定する（docs/tech-stack.md「環境変数」）
const BASE_URL: string = import.meta.env.VITE_API_BASE_URL ?? ''

/** 失敗の種類。画面での表示先が変わる（docs/screens.md「エラーの表示」） */
export type ApiErrorKind =
  /** 400。項目に紐づくエラーは errors に入る */
  | 'validation'
  /** 404 */
  | 'not_found'
  /** 500 */
  | 'server'
  /** 接続できない */
  | 'network'
  /** 一定時間応答がない */
  | 'timeout'
  /** JSON でない応答など */
  | 'unexpected'

export class ApiError extends Error {
  readonly kind: ApiErrorKind
  /** 項目名 → メッセージ（400 のとき。項目に紐づかないエラーでは null） */
  readonly errors: Record<string, string> | null

  constructor(kind: ApiErrorKind, message: string, errors: Record<string, string> | null = null) {
    super(message)
    this.name = 'ApiError'
    this.kind = kind
    this.errors = errors
  }
}

// docs/screens.md「エラーバナーの文言」
const NETWORK_MESSAGE = 'サーバーに接続できませんでした。時間をおいて再度お試しください'
const TIMEOUT_MESSAGE = 'サーバーからの応答がありません。時間をおいて再度お試しください'
const UNEXPECTED_MESSAGE = '予期しない応答を受け取りました'

type Query = Record<string, string | number | null | undefined>

interface RequestOptions {
  query?: Query
  body?: unknown
}

function buildUrl(path: string, query?: Query): string {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query ?? {})) {
    // 未指定（null・undefined・空文字）は送らない。API も空文字は指定なしとして扱う
    if (value !== null && value !== undefined && value !== '') params.set(key, String(value))
  }
  const queryString = params.toString()
  return `${BASE_URL}${path}${queryString ? `?${queryString}` : ''}`
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    throw new ApiError('unexpected', UNEXPECTED_MESSAGE)
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

/** 400・404・500 の本文（{ message, errors? }）から ApiError を作る */
function toApiError(status: number, body: unknown): ApiError {
  const message = isRecord(body) && typeof body.message === 'string' ? body.message : null
  if (message === null) return new ApiError('unexpected', UNEXPECTED_MESSAGE)

  if (status === 400) {
    const errors =
      isRecord(body) && isRecord(body.errors) ? (body.errors as Record<string, string>) : null
    return new ApiError('validation', message, errors)
  }
  if (status === 404) return new ApiError('not_found', message)
  if (status === 500) return new ApiError('server', message)
  return new ApiError('unexpected', UNEXPECTED_MESSAGE)
}

/** API を呼ぶ。成功なら本文を T として返し（204 は undefined）、失敗なら ApiError を投げる */
export async function request<T>(
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  { query, body }: RequestOptions = {},
): Promise<T> {
  let response: Response
  try {
    response = await fetch(buildUrl(path, query), {
      method,
      headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch (error) {
    // AbortSignal.timeout() が打ち切ったときは TimeoutError、接続できないときは TypeError
    if (error instanceof DOMException && error.name === 'TimeoutError') {
      throw new ApiError('timeout', TIMEOUT_MESSAGE)
    }
    throw new ApiError('network', NETWORK_MESSAGE)
  }

  if (response.status === 204) return undefined as T
  const json = await readJson(response)
  if (!response.ok) throw toApiError(response.status, json)
  return json as T
}
