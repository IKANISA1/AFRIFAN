import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ShoppingBag } from "lucide-react";
import type { ShopProduct } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export function ProductCard({ product }: { product: ShopProduct }) {
  const productImage = product.imageUrl ?? "/media/stadium-hero.jpg";

  return (
    <Link
      href={`/shop/${product.id}`}
      prefetch={false}
      className="group glass-panel card-interactive flex h-full flex-col gap-4 rounded-[30px] border border-border-soft p-4"
    >
      <div className="img-zoom relative overflow-hidden rounded-[24px]">
        <Image
          src={productImage}
          alt={product.name}
          width={1200}
          height={840}
          sizes="(min-width: 1024px) 33vw, 100vw"
          quality={60}
          className="h-56 w-full object-cover transition-transform duration-700 ease-out group-hover:scale-110"
        />
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,transparent_40%,rgba(3,10,24,0.82)_100%)]" />
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-3 px-4 py-3">
          <span className="rounded-full bg-black/55 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-white">
            {product.category}
          </span>
          <span className="rounded-full bg-club-accent/85 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-slate-950">
            {product.collection ?? "Official"}
          </span>
        </div>
        
        {/* Hover overlay: Quick preview swatches */}
        <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 backdrop-blur-sm transition-opacity duration-300 group-hover:opacity-100">
          <div className="flex gap-2 translate-y-4 opacity-0 transition-all duration-300 group-hover:translate-y-0 group-hover:opacity-100">
            {['bg-club-primary', 'bg-white', 'bg-slate-900'].map((color, i) => (
              <span key={color} className={`h-6 w-6 rounded-full border-2 border-white/20 shadow-lg ${color}`} style={{ transitionDelay: `${i * 50}ms` }} />
            ))}
          </div>
        </div>
      </div>

      <div className="space-y-2">
        <h3 className="font-display text-3xl font-bold uppercase leading-none text-white">
          {product.name}
        </h3>
        <p className="text-sm leading-7 text-slate-300">{product.subtitle}</p>
      </div>

      <div className="flex flex-wrap gap-2">
        {product.sizes.slice(0, 4).map((size) => (
          <span
            key={size}
            className="rounded-full border border-border-soft bg-white/4 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
          >
            {size}
          </span>
        ))}
      </div>

      <div className="mt-auto flex items-center justify-between gap-3 border-t border-white/8 pt-4">
        <div className="flex items-center gap-2">
          <ShoppingBag size={16} className="text-club-accent" />
          <span className="font-score text-4xl font-bold uppercase text-white">
            {formatCurrency(product.price)}
          </span>
        </div>
        <div className="flex items-center gap-2 text-sm font-semibold text-white">
          View product
          <ArrowRight size={18} className="text-slate-300" />
        </div>
      </div>
    </Link>
  );
}
