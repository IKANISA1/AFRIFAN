import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductCard } from "@/components/product-card";
import { ShareActionButton } from "@/components/pwa/share-action-button";
import { getClubProfile, getProductById, getProducts } from "@/lib/data/public";
import {
  buildPageMetadata,
  buildProductJsonLd,
  renderJsonLdScriptContent,
} from "@/lib/metadata";
import { formatCurrency } from "@/lib/utils";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ productId: string }>;
}): Promise<Metadata> {
  const { productId } = await params;
  const [club, product] = await Promise.all([
    getClubProfile(),
    getProductById(productId),
  ]);

  return buildPageMetadata({
    title: product?.name ?? "Shop product",
    description: product?.subtitle ?? `Official ${club.shortName} merchandise.`,
    path: `/shop/${productId}`,
    imagePath: product?.imageUrl ?? "/media/stadium-hero.jpg",
  });
}

export default async function ProductPage({
  params,
}: {
  params: Promise<{ productId: string }>;
}) {
  const { productId } = await params;
  const [product, products] = await Promise.all([
    getProductById(productId),
    getProducts(),
  ]);

  if (product == null) {
    notFound();
  }

  const relatedProducts = products.filter((entry) => entry.id !== product.id).slice(0, 3);

  return (
    <div className="page-shell section-grid py-12">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: renderJsonLdScriptContent(buildProductJsonLd(product)),
        }}
      />
      <section className="glass-panel-elevated overflow-hidden rounded-[38px]">
        <div className="grid gap-8 lg:grid-cols-[0.95fr_1.05fr]">
          <div className="img-zoom relative min-h-[22rem]">
            <Image
              src={product.imageUrl ?? "/media/stadium-hero.jpg"}
              alt={product.name}
              fill
              sizes="(min-width: 1024px) 44vw, 100vw"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_30%,rgba(3,10,24,0.74)_100%)]" />
          </div>
          <div className="p-6 sm:p-8">
            <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
              {product.collection ?? "Official"} • {product.category}
            </p>
            <h1 className="mt-4 font-display text-6xl font-bold uppercase leading-none text-balance text-white">
              {product.name}
            </h1>
            <p className="mt-4 text-lg leading-8 text-slate-300">{product.subtitle}</p>
            <p className="mt-4 font-score text-6xl text-white">
              {formatCurrency(product.price)}
            </p>
            <div className="mt-5 flex flex-wrap gap-2">
              {product.sizes.map((size) => (
                <span
                  key={size}
                  className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
                >
                  {size}
                </span>
              ))}
            </div>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/supporters"
                className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
              >
                Order in fan app
              </Link>
              <Link
                href="/membership"
                className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
              >
                Unlock member perks
              </Link>
              <ShareActionButton
                title={product.name}
                text={product.subtitle}
                url={`/shop/${product.id}`}
                className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
              />
            </div>
          </div>
        </div>
      </section>

      <div className="grid gap-8 lg:grid-cols-[0.92fr_1.08fr]">
        <div className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
            Product detail
          </p>
          <p className="mt-4 text-base leading-8 text-slate-200">
            {product.description}
          </p>
          <div className="mt-5 grid gap-4">
            {[
              "Collection context keeps every drop feeling like a launch.",
              "Size visibility and price clarity stay prominent before checkout.",
              "Membership and fan app actions support trust instead of blocking discovery.",
            ].map((point) => (
              <div
                key={point}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
              >
                {point}
              </div>
            ))}
          </div>
        </div>

        {relatedProducts.length > 0 ? (
          <section className="section-grid">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                More merch
              </p>
              <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
                Related products
              </h2>
            </div>
            <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
              {relatedProducts.map((relatedProduct) => (
                <ProductCard key={relatedProduct.id} product={relatedProduct} />
              ))}
            </div>
          </section>
        ) : null}
      </div>
    </div>
  );
}
