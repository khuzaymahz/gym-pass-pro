import { ApiError } from "@/lib/api";

export type ActionResult<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; code: string; message: string };

export async function runAction<T>(fn: () => Promise<T>): Promise<ActionResult<T>> {
  try {
    const data = await fn();
    return { ok: true, data };
  } catch (error) {
    if (error instanceof ApiError) {
      return { ok: false, code: error.code, message: error.message };
    }
    const message = error instanceof Error ? error.message : "Unknown error.";
    return { ok: false, code: "UNKNOWN", message };
  }
}
