/// Image-upload guards shared across the partner portal. Mirrors
/// the backend's `settings.max_upload_mb` and `sniff_image` MIME
/// allow-list so the frontend can fail fast with a clear message
/// before the file ever leaves the browser. Backend re-validates
/// magic bytes regardless — this is purely a UX optimization.
///
/// Keep these constants in lockstep with:
///   - backend/app/config.py::Settings.max_upload_mb
///   - backend/app/utils/image_sniff.py::sniff_image
///   - gym-partner/next.config.js::experimental.serverActions.bodySizeLimit

export const MAX_UPLOAD_MB = 10;

export const ACCEPTED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
] as const;

export type AcceptedImageType = (typeof ACCEPTED_IMAGE_TYPES)[number];

/// Comma-joined string suitable for the `<input type="file" accept>`
/// attribute. Memoized as a constant so we don't rejoin on every
/// render.
export const ACCEPTED_IMAGE_TYPES_ATTR = ACCEPTED_IMAGE_TYPES.join(",");

export type ImageValidationError = "unsupported_type" | "too_large";

/// Returns `null` for a valid image, or a discriminator the caller
/// can map to a localized error message. Pure function — caller
/// owns the message rendering.
export function validateImageFile(file: File): ImageValidationError | null {
  if (!isAcceptedImageType(file.type)) return "unsupported_type";
  if (file.size > MAX_UPLOAD_MB * 1024 * 1024) return "too_large";
  return null;
}

function isAcceptedImageType(mime: string): mime is AcceptedImageType {
  return (ACCEPTED_IMAGE_TYPES as readonly string[]).includes(mime);
}
