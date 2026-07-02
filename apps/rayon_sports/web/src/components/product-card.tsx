import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ShoppingBag } from "lucide-react";
import type { ShopProduct } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";
import { ui } from "@/ui-kit";

export function ProductCard({ product }: { product: ShopProduct }) {
  const productImage = product.imageUrl ?? "/media/stadium-hero.jpg";

  return (
    <Link
      href={`/shop/${product.id}`}
      prefetch={false}
      className={`group ${ui.panel} ${ui.cardInteractive} flex h-full flex-col gap-5 rounded-[32px] border-[1.2px] bg-slate-950/96 p-4 sm:p-5`}
    >
      <div className="img-zoom relative overflow-hidden rounded-[26px]">
        <Image
          src={productImage}
          alt={product.name}
          width={1200}
          height={840}
          sizes="(min-width: 1024px) 33vw, 100vw"
          quality={60}
          className="h-60 w-full object-cover transition-transform duration-700 ease-out group-hover:scale-110"
        />
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,transparent_35%,rgba(3,10,24,0.9)_100%)]" />
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-3 px-4 py-3">
          <span className={`${ui.chip} bg-black/45 px-3 py-1 text-[10px] text-white`}>
            {product.category}
          </span>
          <span className={`${ui.chip} bg-club-accent/85 px-3 py-1 text-[10px] text-slate-950`}>
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

      <div className="space-y-3">
        <h3 className="font-display text-[2rem] font-bold uppercase leading-[0.92] tracking-[-0.055em] text-white sm:text-[2.3rem]">
          {product.name}
        </h3>
        <p className="text-sm leading-7 text-slate-100">{product.subtitle}</p>
      </div>

      <div className="flex flex-wrap gap-2">
        {product.sizes.slice(0, 4).map((size) => (
          <span
            key={size}
            className={`${ui.chip} ${ui.chipMuted} text-[11px]`}
          >
            {size}
          </span>
        ))}
      </div>

      <div className="mt-auto flex items-center justify-between gap-3 border-t border-white/10 pt-4">
        <div className="flex items-center gap-2">
          <ShoppingBag size={16} className="text-club-accent" />
          <span className="font-score text-4xl font-bold uppercase tracking-[-0.05em] text-white">
            {formatCurrency(product.price)}
          </span>
        </div>
        <div className="flex items-center gap-2 text-sm font-semibold uppercase tracking-[0.18em] text-white">
          View product
          <ArrowRight size={18} className="text-slate-100 transition-transform duration-300 group-hover:translate-x-1" />
        </div>
      </div>
    </Link>
  );
}
