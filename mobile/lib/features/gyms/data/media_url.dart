/// Resolve a media URL returned by the backend to an absolute URL the
/// device can fetch. Two shapes come over the wire:
///
///   1. **Absolute** — `https://images.unsplash.com/...` for seeded
///      placeholder media. Returned untouched.
///   2. **Relative** — `/media/gym_logos/<id>/<filename>` for logos
///      and photos uploaded via the admin console. Prefixed with
///      the configured API base URL (`http://localhost:8000` in dev,
///      `https://api.gym-pass.net` in prod) so the same value works
///      in both environments without a code change.
///
/// Lives in `data/` because it's the bridge between the wire shape
/// and the rendering layer; presentation code can stay ignorant of
/// URL conventions.
String resolveMediaUrl(String apiBaseUrl, String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '$apiBaseUrl$url';
}
