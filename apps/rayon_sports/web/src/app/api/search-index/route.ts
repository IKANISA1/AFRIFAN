import { NextResponse } from "next/server";
import { getSiteSearchIndex } from "@/lib/data/public";

export const revalidate = 300;

export async function GET() {
  const items = await getSiteSearchIndex();
  return NextResponse.json({ items });
}
