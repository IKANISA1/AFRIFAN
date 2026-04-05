"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { ArrowRight, ShoppingBag } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackProducts } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { ShopOrder, ShopProduct } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export default function FanShopPage() {
  const { client, user } = useFanPortal();
  const [products, setProducts] = useState<ShopProduct[]>(fallbackProducts);
  const [orders, setOrders] = useState<ShopOrder[]>([]);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadData() {
      const [productRows, orderRows] = await Promise.all([
        activeClient
          .from("shop_products")
          .select("*")
          .eq("club_id", rayonClub.numericId)
          .eq("is_active", true)
          .order("sort_order", { ascending: true }),
        activeClient
          .from("shop_orders")
          .select("*")
          .eq("user_id", activeUser.id)
          .order("created_at", { ascending: false }),
      ]);

      if (productRows.data && productRows.data.length > 0) {
        setProducts(
          productRows.data.map((row) => ({
            id: String(row.id),
            name: String(row.name ?? "Product"),
            subtitle: String(row.subtitle ?? row.description ?? "Official"),
            description: String(row.description ?? row.subtitle ?? "Official"),
            category: String(row.category ?? "Merch"),
            price: Number(row.price ?? 0),
            imageUrl: row.image_url ? String(row.image_url) : null,
            sizes: Array.isArray(row.sizes)
              ? row.sizes.map((value: unknown) => String(value))
              : ["One Size"],
            isActive: row.is_active !== false,
            collection: row.collection ? String(row.collection) : null,
          })),
        );
      }

      if (orderRows.data) {
        setOrders(
          orderRows.data.map((row) => ({
            id: String(row.id),
            userId: String(row.user_id),
            total: Number(row.total ?? 0),
            status: String(row.status ?? "pending"),
            deliveryAddress: row.delivery_address
              ? String(row.delivery_address)
              : null,
            momoReference: row.momo_reference ? String(row.momo_reference) : null,
            createdAt: String(row.created_at),
          })),
        );
      }
    }

    loadData().catch(() => {});
  }, [client, user]);

  async function placeOrder(formData: FormData) {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    setStatus("Placing order...");

    try {
      const productId = String(formData.get("productId") ?? "");
      const quantity = Number(formData.get("quantity") ?? "1");
      const deliveryAddress = String(formData.get("deliveryAddress") ?? "");
      const product = products.find((entry) => entry.id === productId);

      if (product == null) {
        throw new Error("Product not found.");
      }

      const total = product.price * quantity;

      await activeClient.from("shop_orders").insert({
        user_id: activeUser.id,
        club_id: rayonClub.numericId,
        partner_id: rayonClub.numericId.toString(),
        items: [
          {
            product,
            quantity,
            selected_variant: product.sizes[0] ?? "One Size",
          },
        ],
        subtotal: total,
        discount_amount: 0,
        delivery_fee: 0,
        total,
        delivery_address: deliveryAddress,
        momo_reference: `WEB-SHOP-${Date.now()}`,
        status: "pending",
      });

      const { data } = await activeClient
        .from("shop_orders")
        .select("*")
        .eq("user_id", activeUser.id)
        .order("created_at", { ascending: false });

      if (data) {
        setOrders(
          data.map((row) => ({
            id: String(row.id),
            userId: String(row.user_id),
            total: Number(row.total ?? 0),
            status: String(row.status ?? "pending"),
            deliveryAddress: row.delivery_address
              ? String(row.delivery_address)
              : null,
            momoReference: row.momo_reference ? String(row.momo_reference) : null,
            createdAt: String(row.created_at),
          })),
        );
      }

      setStatus("Order placed — we'll confirm when it's ready for pickup.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Order failed.");
    }
  }

  const featuredProduct = products[0];

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Club shop"
        title="Official Rayon Sports gear."
        description="Replica kits, matchday scarves, and supporter essentials — pick your drop, place the order, collect before kickoff."
        stats={[
          { label: "Products", value: products.length.toString() },
          { label: "My orders", value: orders.length.toString() },
          { label: "Collections", value: [...new Set(products.map((p) => p.collection).filter(Boolean))].length.toString() },
        ]}
        actions={
          <>
            <a
              href="#shop-order"
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              Place order <ShoppingBag size={18} />
            </a>
            <a
              href="#order-history"
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-white/5 px-5 py-3 font-semibold text-white transition hover:bg-white/10"
            >
              My orders <ArrowRight size={18} />
            </a>
          </>
        }
        media={
          featuredProduct ? (
            <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
              <Image
                src={featuredProduct.imageUrl ?? "/media/stadium-hero.jpg"}
                alt={featuredProduct.name}
                width={1200}
                height={720}
                sizes="(min-width: 1024px) 30vw, 100vw"
                className="h-40 w-full rounded-[22px] object-cover"
              />
              <p className="mt-4 font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
                {featuredProduct.collection ?? featuredProduct.category}
              </p>
              <p className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white">
                {featuredProduct.name}
              </p>
              <p className="mt-2 text-sm leading-6 text-slate-300">
                {featuredProduct.subtitle}
              </p>
              <p className="mt-4 font-display text-2xl font-bold uppercase text-white">
                {formatCurrency(featuredProduct.price)}
              </p>
            </article>
          ) : null
        }
      />

      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <form id="shop-order" action={placeOrder} className="glass-panel-elevated grid gap-5 rounded-[32px] p-6">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Order
            </p>
            <h2 className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
              Pick your gear.
            </h2>
          </div>
          <label className="grid gap-2 text-sm">
            Product
            <select
              name="productId"
              className="dashboard-input"
              defaultValue={products[0]?.id}
            >
              {products.map((product) => (
                <option key={product.id} value={product.id}>
                  {product.name} • {formatCurrency(product.price)}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-2 text-sm">
            Quantity
            <input
              name="quantity"
              type="number"
              min="1"
              max="10"
              defaultValue="1"
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            Delivery address
            <textarea
              name="deliveryAddress"
              rows={3}
              className="dashboard-input"
              defaultValue=""
            />
          </label>
          <button
            type="submit"
            className="rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            Place order
          </button>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </form>

        <div className="grid gap-5">
          <div className="grid gap-5 md:grid-cols-2">
            {products.slice(0, 4).map((product) => (
              <article key={product.id} className="glass-panel card-interactive rounded-[28px] p-4">
                <Image
                  src={product.imageUrl ?? "/media/stadium-hero.jpg"}
                  alt={product.name}
                  width={1200}
                  height={720}
                  sizes="(min-width: 1024px) 24vw, 100vw"
                  className="h-40 w-full rounded-[22px] object-cover"
                />
                <p className="mt-4 font-display text-3xl font-bold uppercase leading-none">
                  {product.name}
                </p>
                <p className="mt-2 text-sm leading-6 text-slate-300">
                  {product.subtitle}
                </p>
                <p className="mt-4 font-display text-2xl font-bold uppercase">
                  {formatCurrency(product.price)}
                </p>
              </article>
            ))}
          </div>

          <div id="order-history" className="glass-panel rounded-[30px] p-5">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                  Order history
                </p>
                <p className="mt-3 font-display text-3xl font-bold uppercase leading-none">
                  My orders
                </p>
              </div>
            </div>
            <div className="mt-5 grid gap-3">
              {orders.length > 0 ? (
                orders.map((order) => (
                  <div
                    key={order.id}
                    className="rounded-[22px] border border-border-soft bg-white/6 p-4 text-sm text-slate-200"
                  >
                    <p className="font-semibold uppercase tracking-[0.2em] text-club-accent">
                      {order.status}
                    </p>
                    <p className="mt-2">{formatCurrency(order.total)}</p>
                    <p className="mt-1 text-slate-300">
                      {order.deliveryAddress ?? "Delivery address pending"}
                    </p>
                  </div>
                ))
              ) : (
                <p className="rounded-[22px] border border-dashed border-border-soft bg-white/4 px-5 py-6 text-sm leading-7 text-slate-300">
                  Your order history will appear here after your first purchase.
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
