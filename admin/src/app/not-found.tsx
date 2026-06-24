import Link from "next/link";

/// 404 boundary — shown for unknown routes and any `notFound()` call
/// (e.g. a user/gym detail page whose id doesn't resolve). Renders
/// within the root layout, so it inherits the design system.
export default function NotFound() {
  return (
    <div className="mx-auto flex min-h-[60vh] max-w-md flex-col justify-center gap-4 py-16">
      <p className="label">Admin · 404</p>
      <h1 className="h2">We couldn&apos;t find that page</h1>
      <p className="text-[13px] leading-relaxed text-muted">
        The link may be out of date, or the record was removed. Head back to
        the dashboard to keep going.
      </p>
      <div className="mt-2">
        <Link href="/" className="btn-primary btn-sm">
          Go to dashboard
        </Link>
      </div>
    </div>
  );
}
