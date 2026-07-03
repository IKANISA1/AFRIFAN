import Image from "next/image";
import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { ProductCard } from "@/components/product-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getProducts } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatCurrency } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.shop.metaTitle(club),
    description: copy.pages.shop.metaDescription(club),
    path: "/shop",
  });
}

export default async function ShopPage() {
  const featureGate = await getFeaturePageGuard("shop");
  if (featureGate) {
    return featureGate;
  }

  const [club, products] = await Promise.all([getClubProfile(), getProducts()]);
  const copy = getSiteCopy(club.defaultLanguage);
  const [featuredProduct, ...catalogue] = products;
  const categories = Array.from(new Set(products.map((product) => product.category)));

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.shop.eyebrow}
        title={copy.pages.shop.title}
        description={copy.pages.shop.description(club)}
        actions={
          <>
            <Link
              href="/supporters"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.shopInFanApp}
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.memberPerks}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.products, value: products.length.toString() },
          { label: copy.common.categories, value: categories.length.toString() },
          {
            label: copy.common.from,
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
                src={featuredProduct.imageUrl ?? "/brand-surface.svg"}
                alt={featuredProduct.name}
                fill
                sizes="(min-width: 1280px) 35vw, 100vw"
                className="object-cover"
              />
              <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_25%,rgba(3,10,24,0.62)_100%)]" />
            </div>
            <div className="p-6 sm:p-8">
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                {copy.pages.shop.featuredDrop}
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
                {copy.common.openProduct}
              </Link>
            </div>
          </article>

          <div className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.shop.shopStandards}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.shop.clearBeforeCheckout}
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
              {copy.pages.shop.standardsPoints.map((point) => (
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
              {copy.pages.shop.unlockMemberDiscounts} <ShieldCheck size={18} />
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
