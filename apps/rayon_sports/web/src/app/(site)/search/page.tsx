import Link from "next/link";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteSearchIndex } from "@/lib/data/public";

export const metadata = buildPageMetadata({
  title: "Search",
  description: "Search fixtures, tickets, membership, circles, shop, and club news.",
});

interface SearchPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

function normalizeQueryValue(value: string | string[] | undefined) {
  if (Array.isArray(value)) {
    return value[0]?.trim() ?? "";
  }

  return value?.trim() ?? "";
}

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const params = await searchParams;
  const query = normalizeQueryValue(params.q);
  const items = await getSiteSearchIndex();
  const term = query.toLowerCase();

  const results = term
    ? items.filter((item) => {
        const haystack =
          `${item.title} ${item.description} ${item.meta ?? ""} ${item.category}`.toLowerCase();
        return haystack.includes(term);
      })
    : items.slice(0, 18);

  return (
    <section className="page-shell section-grid pb-20 pt-8">
      <div className="glass-panel-elevated rounded-[34px] p-6 sm:p-8">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Search
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          Find it fast.
        </h1>
        <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300 sm:text-base">
          Fixtures, matchday details, supporter products, membership tiers, and club news.
        </p>

        <form action="/search" className="mt-6 flex flex-col gap-3 sm:flex-row">
          <input
            type="search"
            name="q"
            defaultValue={query}
            placeholder="Search fixtures, news, circles, or shop"
            className="min-h-12 flex-1 rounded-full border border-border-soft bg-white/5 px-5 text-base text-white outline-none placeholder:text-slate-500"
          />
          <button
            type="submit"
            className="min-h-12 rounded-full bg-club-primary px-6 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Search
          </button>
        </form>
      </div>

      <div className="grid gap-3">
        {results.length > 0 ? (
          results.slice(0, 24).map((item) => (
            <Link
              key={item.id}
              href={item.href}
              className="glass-panel card-interactive rounded-[24px] p-5"
            >
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full bg-club-primary/18 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                  {item.category}
                </span>
                {item.meta ? (
                  <span className="text-[11px] uppercase tracking-[0.22em] text-slate-500">
                    {item.meta}
                  </span>
                ) : null}
              </div>
              <p className="mt-3 text-lg font-semibold text-white">{item.title}</p>
              <p className="mt-2 text-sm leading-6 text-slate-300">{item.description}</p>
            </Link>
          ))
        ) : (
          <div className="glass-panel rounded-[24px] px-5 py-10 text-center">
            <p className="font-display text-3xl font-bold uppercase text-white">
              No results
            </p>
            <p className="mt-3 text-sm leading-7 text-slate-300">
              Try fixtures, tickets, membership, circles, or shop.
            </p>
          </div>
        )}
      </div>
    </section>
  );
}
