import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { ProductCard } from "@/components/product-card";
import { SectionHeading } from "@/components/section-heading";
import { clubHistoryMoments } from "@/lib/content";
import { getProducts } from "@/lib/data/public";

export async function ShopAndIdentityBlock() {
  const products = await getProducts();

  return (
    <section className="page-shell grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
      <div className="glass-panel rounded-[34px] p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <SectionHeading
            eyebrow="Shop"
            title="Wear the badge."
          />
          <Link
            href="/shop"
            className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Shop all <ArrowRight size={18} />
          </Link>
        </div>
        <div className="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {products.slice(0, 3).map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </div>

      <div className="grid gap-6">
        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Club identity"
            title="Gikundiro — the beloved."
          />
          <div className="mt-6 grid gap-4">
            {clubHistoryMoments.map((moment) => (
              <article
                key={moment.title}
                className="rounded-[24px] border border-border-soft bg-white/5 p-5"
              >
                <p className="font-display text-2xl font-bold uppercase leading-none text-white">
                  {moment.title}
                </p>
                <p className="mt-3 line-clamp-1 text-sm leading-7 text-slate-300">
                  {moment.body}
                </p>
              </article>
            ))}
          </div>
        </div>
        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Fan portal"
            title="Your supporter account."
          />
          <div className="mt-6 flex flex-wrap gap-3">
            <Link
              href="/app"
              className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-primary-light"
            >
              Continue to portal
            </Link>
            <Link
              href="/history"
              className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
            >
              Explore club history
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
