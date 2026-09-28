/// Every refusal the API gives, as the one-word code the app maps onto `ContractError`.
/// The body is always `{ "error": "<code>" }` -- never a sentence, never a stack.
export const ERROR_STATUS = {
  not_signed_in: 401,
  not_member: 403,
  not_owner: 403,
  bad_signature: 403,
  banned: 403,
  room_not_found: 404,
  invalid_code: 404,
  room_full: 409,
  slot_already_posted: 409,
  too_large: 413,
  clip_too_long: 422,
  rate_limited: 429,
  unsupported: 501,
  bad_request: 400,
  gone: 410,
  not_found: 404,
  server_error: 500,
} as const;

export type ErrorCode = keyof typeof ERROR_STATUS;

export class ApiError extends Error {
  readonly code: ErrorCode;

  constructor(code: ErrorCode, detail?: string) {
    super(detail ?? code);
    this.code = code;
  }

  get status(): (typeof ERROR_STATUS)[ErrorCode] {
    return ERROR_STATUS[this.code];
  }
}

export function fail(code: ErrorCode, detail?: string): never {
  throw new ApiError(code, detail);
}

export function errorResponse(code: ErrorCode): Response {
  return Response.json({ error: code }, { status: ERROR_STATUS[code] });
}
