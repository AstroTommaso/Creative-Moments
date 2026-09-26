import { NextResponse } from "next/server";
import { ZodError } from "zod";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status });
}

export function errorResponse(err: unknown) {
  if (err instanceof ApiError) {
    return json({ error: err.message }, err.status);
  }
  if (err instanceof ZodError) {
    return json({ error: "invalid_request", details: err.flatten() }, 400);
  }
  console.error(err);
  return json({ error: "internal_error" }, 500);
}

/** Wraps a route handler so any thrown ApiError/ZodError becomes the right JSON response. */
export function withErrorHandling<Args extends unknown[]>(
  handler: (...args: Args) => Promise<Response>,
) {
  return async (...args: Args): Promise<Response> => {
    try {
      return await handler(...args);
    } catch (err) {
      return errorResponse(err);
    }
  };
}
