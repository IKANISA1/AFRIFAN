import Image from "next/image";
import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { ProductCard } from "@/components/product-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getProducts } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { formatCurrency } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: `${club.shortName} shop`,
    description: `Official ${club.shortName} merch, jerseys, travel wear, scarves, and supporter essentials.`,
    path: "/shop",
  });
}

export default async function ShopPage() {
  const [club, products] = await Promise.all([getClubProfile(), getProducts()]);
  const [featuredProduct, ...catalogue] = products;
  const categories = Array.from(new Set(products.map((product) => product.category)));

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Club shop"
        title="Official merch and matchday essentials."
        description={`Browse the latest ${club.shortName} drop, check sizes and pricing, and continue secure checkout in the fan app.`}
        actions={
          <>
            <Link
              href="/supporters"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Shop in fan app
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Member perks
            </Link>
          </>
        }
        stats={[
          { label: "Products", value: products.length.toString() },
          { label: "Categories", value: categories.length.toString() },
          {
            label: "From",
            value: formatCurrency(
              products.reduce(
                (lowest, product) => Math.min(lowest, product.price),
                products[0]?.price ?? 0,
              ),
            ),
          },
        ]}
      />

      {featuredProduct ? (
        <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
          <article className="glass-panel card-interactive grid overflow-hidden rounded-[34px] lg:grid-cols-[0.95fr_1.05fr]">
            <div className="img-zoom relative min-h-[18rem]">
              <Image
                src={featuredProduct.imageUrl ?? "/media/stadium-hero.jpg"}
                alt={featuredProduct.name}
                fill
                sizes="(min-width: 1280px) 35vw, 100vw"
                className="object-cover"
              />
              <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_25%,rgba(3,10,24,0.62)_100%)]" />
            </div>
            <div className="p-6 sm:p-8">
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                Featured drop
              </p>
              <h2 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white text-balance">
                {featuredProduct.name}
              </h2>
              <p className="mt-4 text-base leading-8 text-slate-300">
                {featuredProduct.subtitle}
              </p>
              <p className="mt-3 font-score text-5xl font-bold uppercase text-white">
                {formatCurrency(featuredProduct.price)}
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                {featuredProduct.sizes.map((size) => (
                  <span
                    key={size}
                    className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
                  >
                    {size}
                  </span>
                ))}
              </div>
              <Link
                href={`/shop/${featuredProduct.id}`}
                className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
              >
                Open product
              </Link>
            </div>
          </article>

          <div className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Shop standards
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Clear before checkout
            </h2>
            <div className="mt-5 flex flex-wrap gap-2">
              {categories.map((category) => (
                <span
                  key={category}
                  className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
                >
                  {category}
                </span>
              ))}
            </div>
            <div className="mt-5 grid gap-4">
              {[
                "Product imagery and collection context lead every launch.",
                "Sizes and prices are visible before the supporter leaves the public site.",
                "The fan app handles checkout while the public shop handles discovery.",
              ].map((point) => (
                <div
                  key={point}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
                >
                  {point}
                </div>
              ))}
            </div>
            <Link
              href="/membership"
              className="mt-6 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
            >
              Unlock member discounts <ShieldCheck size={18} />
            </Link>
          </div>
        </section>
      ) : null}

      <section className="section-grid">
        <div className="flex flex-wrap gap-2">
          {categories.map((category) => (
            <span
              key={category}
              className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
            >
              {category}
            </span>
          ))}
        </div>
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {(catalogue.length > 0 ? catalogue : products).map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>
    </div>
  );
}
