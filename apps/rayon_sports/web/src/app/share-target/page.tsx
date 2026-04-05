import Link from "next/link";
import { siteConfig } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";

export const metadata = buildPageMetadata({
  title: "Shared into Gikundiro",
  description: "Review shared content and continue inside the Rayon Sports PWA.",
  path: "/share-target",
  robots: {
    index: false,
    follow: false,
  },
});

interface ShareTargetPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

function firstValue(value: string | string[] | undefined) {
  if (Array.isArray(value)) {
    return value[0] ?? "";
  }

  return value ?? "";
}

export default async function ShareTargetPage({
  searchParams,
}: ShareTargetPageProps) {
  const params = await searchParams;
  const title = firstValue(params.title).trim();
  const text = firstValue(params.text).trim();
  const url = firstValue(params.url).trim();
  const query = [title, text, url].filter(Boolean).join(" ").trim();

  return (
    <section className="page-shell section-grid py-12">
      <div className="glass-panel-elevated rounded-[34px] p-6 sm:p-8">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Shared into Gikundiro
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          Bring shared content into the club flow.
        </h1>
        <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300 sm:text-base">
          Gikundiro can receive shared text and links from the system share sheet,
          then route you into search, the fan portal, or matchday actions.
        </p>

        <div className="mt-6 grid gap-4">
          {title ? (
            <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
              <p className="text-xs uppercase tracking-[0.22em] text-slate-500">
                Title
              </p>
              <p className="mt-2 text-base text-white">{title}</p>
            </div>
          ) : null}
          {text ? (
            <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
              <p className="text-xs uppercase tracking-[0.22em] text-slate-500">
                Text
              </p>
              <p className="mt-2 text-base text-white">{text}</p>
            </div>
          ) : null}
          {url ? (
            <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
              <p className="text-xs uppercase tracking-[0.22em] text-slate-500">
                Link
              </p>
              <p className="mt-2 break-all text-base text-white">{url}</p>
            </div>
          ) : null}
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href={query ? `/search?q=${encodeURIComponent(query)}` : "/search"}
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Search inside Gikundiro
          </Link>
          <Link
            href={siteConfig.fansUrl}
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Open fan portal
          </Link>
          {url ? (
            <a
              href={url}
              target="_blank"
              rel="noreferrer"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Open original link
            </a>
          ) : null}
        </div>
      </div>
    </section>
  );
}
