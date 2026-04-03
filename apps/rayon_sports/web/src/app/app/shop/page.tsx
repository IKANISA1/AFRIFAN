"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/section-heading";
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

      setStatus("Order created and awaiting payment confirmation.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Order failed.");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Shop portal"
        title="Create club merchandise orders from the browser."
        description="The order record is written into the same shared commerce layer used by the mobile app."
      />
      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <form action={placeOrder} className="glass-panel grid gap-5 rounded-[32px] p-6">
          <label className="grid gap-2 text-sm">
            Product
            <select
              name="productId"
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
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
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
            />
          </label>
          <label className="grid gap-2 text-sm">
            Delivery address
            <textarea
              name="deliveryAddress"
              rows={4}
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
              defaultValue=""
            />
          </label>
          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Place order
          </button>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </form>

        <div className="grid gap-5">
          <div className="grid gap-5 md:grid-cols-2">
            {products.slice(0, 4).map((product) => (
              <article key={product.id} className="glass-panel rounded-[28px] p-4">
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
          <div className="glass-panel rounded-[30px] p-5">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              My orders
            </p>
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
                    <p className="mt-1 text-slate-400">
                      {order.deliveryAddress ?? "Delivery address pending"}
                    </p>
                  </div>
                ))
              ) : (
                <p className="text-sm leading-7 text-slate-300">
                  Orders will appear here after your first portal checkout.
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
