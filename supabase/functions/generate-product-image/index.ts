import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type AllowedProductType =
  | "kit"
  | "jacket"
  | "scarf"
  | "ball"
  | "guards"
  | "accessory"
  | "news";

type AllowedTargetTable = "shop_products" | "news_articles";

type GenerateRequest = {
  clubId?: unknown;
  productType?: unknown;
  productName?: unknown;
  targetTable?: unknown;
  targetId?: unknown;
};

type ClubBrand = {
  club_name: string;
  primary_brand_colors: string;
  nickname_brand_identity: string;
  country_name: string;
  region: string;
  league: string;
};

type GeminiImageResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<Record<string, unknown>>;
    };
  }>;
};

type GenerateProductImageDependencies = {
  createAdminClient: typeof createAdminClient;
  validateRequest: typeof validateRequest;
  fetchFn: typeof fetch;
  randomId: () => string;
};

const defaultDependencies: GenerateProductImageDependencies = {
  createAdminClient,
  validateRequest,
  fetchFn: fetch,
  randomId: () => crypto.randomUUID().substring(0, 8),
};

const PRODUCT_TYPES = new Set<AllowedProductType>([
  "kit",
  "jacket",
  "scarf",
  "ball",
  "guards",
  "accessory",
  "news",
]);

const TARGET_TABLES = new Map<string, AllowedTargetTable>([
  ["shop_products", "shop_products"],
  ["rs_shop_products", "shop_products"],
  ["news_articles", "news_articles"],
  ["rs_news_articles", "news_articles"],
]);

const PROMPT_TEMPLATES: Record<AllowedProductType, (b: ClubBrand) => string> = {
  kit: (b) =>
    `Professional football match jersey in ${b.primary_brand_colors} colors, ` +
    `inspired by ${b.club_name} (${b.nickname_brand_identity}) from ${b.country_name}, ` +
    `${b.region} football culture, premium matchwear on a matte black mannequin torso, ` +
    `product photography on solid dark background, dramatic stadium-style lighting, ` +
    `clean athletic design with subtle geometric texture, cinematic composition, ` +
    `ultra-high detail, sportswear catalog style, absolutely no text or logos or brand names`,
  jacket: (b) =>
    `Premium tactical sports jacket in dark charcoal with ${b.primary_brand_colors} accent stitching, ` +
    `inspired by ${b.club_name} (${b.nickname_brand_identity}) performance outerwear, ` +
    `athletic fit, water-resistant shell fabric, hanging on a matte black display, ` +
    `product photography on dark textured concrete background, ${b.country_name} football culture, ` +
    `dramatic low-key lighting, sportswear catalog, absolutely no text or logos or brand names`,
  scarf: (b) =>
    `Luxury knitted football supporter scarf in ${b.primary_brand_colors} colors, ` +
    `heritage cable-knit pattern inspired by ${b.club_name} (${b.nickname_brand_identity}), ` +
    `${b.country_name} football tradition, fan collectible, folded elegantly, ` +
    `product photography on dark fabric background, warm dramatic lighting, ` +
    `premium catalog style, absolutely no text or logos or brand names`,
  ball: (b) =>
    `Professional match football with ${b.primary_brand_colors} colored panels, ` +
    `inspired by ${b.club_name} official match ball, FIFA quality construction, ` +
    `textured synthetic leather, centered on dark slate surface, ` +
    `product photography with dramatic rim lighting, ${b.country_name} football, ` +
    `premium equipment catalog, absolutely no text or logos or brand names`,
  guards: (b) =>
    `Professional carbon fiber shin guards with ${b.primary_brand_colors} accent details, ` +
    `inspired by ${b.club_name} (${b.nickname_brand_identity}) protective equipment, ` +
    `sleek anatomical design, pair arranged on dark slate surface, ` +
    `product photography on dark background, dramatic lighting, ` +
    `premium sports equipment catalog, absolutely no text or logos or brand names`,
  accessory: (b) =>
    `Premium football fan accessory in ${b.primary_brand_colors} colors, ` +
    `inspired by ${b.club_name} (${b.nickname_brand_identity}) from ${b.country_name}, ` +
    `${b.region} football supporter merchandise, ` +
    `product photography on dark background, dramatic lighting, ` +
    `premium catalog style, absolutely no text or logos or brand names`,
  news: (b) =>
    `African football stadium atmosphere at night in ${b.country_name}, ` +
    `passionate crowd with ${b.primary_brand_colors} team colors visible, ` +
    `${b.nickname_brand_identity} supporters celebrating, ` +
    `cinematic wide angle photojournalistic shot, dramatic floodlights, ` +
    `${b.region} football culture, matchday energy, high detail, ` +
    `absolutely no text overlay or watermarks`,
};

const TOP_CLUB_OVERRIDES: Record<string, Partial<Record<AllowedProductType, string>>> =
  {
    "Rayon Sports FC": {
      kit:
        "Professional football match jersey in royal blue and pure white, " +
        "Rayon Sports Gikundiro style, Rwandan football club, clean modern design, " +
        "blue body with white shoulder panels, athletic fit on matte black mannequin, " +
        "product photography on solid dark background, dramatic stadium lighting, " +
        "premium sportswear catalog, absolutely no text or logos or brand names",
      news:
        "Kigali football stadium at night, passionate Rayon Sports fans in blue and white, " +
        "Gikundiro supporters with scarves raised, Rwandan football atmosphere, " +
        "Amahoro National Stadium environment, cinematic wide angle, dramatic floodlights, " +
        "photojournalistic matchday energy, absolutely no text overlay",
    },
    "Young Africans (Yanga)": {
      kit:
        "Professional football jersey in vivid green and bright yellow, " +
        "Young Africans Yanga Wananchi style, Tanzanian football powerhouse, " +
        "green body with yellow v-neck collar and sleeve trim, " +
        "on matte black mannequin, product photography dark background, " +
        "dramatic lighting, sportswear catalog, absolutely no text or logos",
      news:
        "Benjamin Mkapa National Stadium Dar es Salaam at night, packed with Yanga fans " +
        "in green and yellow, Wananchi banners, Tanzanian football atmosphere, " +
        "cinematic wide angle, floodlights, photojournalistic, no text overlay",
    },
    "Kaizer Chiefs FC": {
      kit:
        "Professional football jersey in rich gold and black, " +
        "Kaizer Chiefs Amakhosi style, South African football, " +
        "gold body with black collar and trim, on matte black mannequin, " +
        "product photography dark background, dramatic stadium lighting, " +
        "premium catalog, absolutely no text or logos or brand names",
      news:
        "FNB Stadium Johannesburg at night packed with Kaizer Chiefs fans in gold and black, " +
        "Amakhosi supporters with scarves, South African football atmosphere, " +
        "cinematic photojournalistic, dramatic floodlights, no text overlay",
    },
    "Simba SC": {
      kit:
        "Professional football jersey in bold red and white, " +
        "Simba SC Wekundu wa Msimbazi style, Tanzanian football, " +
        "red body with white side panels, on matte black mannequin, " +
        "product photography dark background, dramatic lighting, " +
        "sportswear catalog, absolutely no text or logos",
      news:
        "Benjamin Mkapa Stadium filled with Simba SC fans in red and white, " +
        "Msimbazi supporters, Tanzanian Kariakoo atmosphere, " +
        "cinematic wide angle night match, floodlights, no text overlay",
    },
    "TP Mazembe": {
      kit:
        "Professional football jersey in stark black and white vertical stripes, " +
        "TP Mazembe Les Corbeaux (The Ravens) style, Congolese football, " +
        "black and white striped body, on matte black mannequin, " +
        "product photography dark background, dramatic lighting, " +
        "premium catalog, absolutely no text or logos",
      news:
        "Stade TP Mazembe Lubumbashi at night, Les Corbeaux fans in black and white, " +
        "Congolese DR Congo football atmosphere, packed stands, " +
        "cinematic photojournalistic, dramatic floodlights, no text overlay",
    },
    "Orlando Pirates FC": {
      kit:
        "Professional football jersey in black with white skull-and-crossbones inspired design, " +
        "Orlando Pirates Buccaneers style, South African football, " +
        "black body with subtle white diagonal sash, on matte black mannequin, " +
        "product photography dark background, dramatic lighting, " +
        "premium catalog, absolutely no text or logos or brand names",
      news:
        "Orlando Stadium Soweto at night packed with Orlando Pirates fans in black and white, " +
        "Buccaneers supporters, South African football culture, " +
        "cinematic photojournalistic, floodlights, no text overlay",
    },
    "AS Vita Club": {
      kit:
        "Professional football jersey in deep green and black, " +
        "AS Vita Club Les Dauphins Noirs style, Congolese football, " +
        "green body with black collar and trim, on matte black mannequin, " +
        "product photography dark background, dramatic lighting, " +
        "sportswear catalog, absolutely no text or logos",
    },
    "St. George SC": {
      kit:
        "Professional football jersey in bright yellow and red, " +
        "St George SC Faresoch style, Ethiopian football, " +
        "yellow body with red arm bands, on matte black mannequin, " +
        "product photography dark background, dramatic lighting, " +
        "sportswear catalog, absolutely no text or logos",
    },
  };

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeClubId(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
}

function normalizeProductType(value: unknown): AllowedProductType | null {
  const normalized = asTrimmedString(value)?.toLowerCase();
  if (!normalized || !PRODUCT_TYPES.has(normalized as AllowedProductType)) {
    return null;
  }
  return normalized as AllowedProductType;
}

function normalizeTargetTable(value: unknown): AllowedTargetTable | null {
  const normalized = asTrimmedString(value)?.toLowerCase();
  return normalized ? TARGET_TABLES.get(normalized) ?? null : null;
}

function buildPrompt(
  brand: ClubBrand,
  productType: AllowedProductType,
  productName: string | null,
): string {
  const overrides = TOP_CLUB_OVERRIDES[brand.club_name];
  let prompt = overrides?.[productType] ?? PROMPT_TEMPLATES[productType](brand);
  if (productName) {
    prompt += `, product named "${productName}"`;
  }
  return prompt;
}

export function createGenerateProductImageHandler(
  dependencies: Partial<GenerateProductImageDependencies> = {},
) {
  const deps: GenerateProductImageDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }

    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    try {
      const body = await request.json() as GenerateRequest;
      const clubId = normalizeClubId(body.clubId);
      const productType = normalizeProductType(body.productType);
      const productName = asTrimmedString(body.productName);
      const targetTable = normalizeTargetTable(body.targetTable);
      const targetId = asTrimmedString(body.targetId);

      if (clubId == null || productType == null) {
        return jsonError("clubId and productType are required.", 400);
      }

      if (body.targetTable != null && targetTable == null) {
        return jsonError(
          "targetTable must be one of shop_products or news_articles.",
          400,
        );
      }

      if ((targetTable == null) !== (targetId == null)) {
        return jsonError(
          "targetTable and targetId must be provided together.",
          400,
        );
      }

      const validated = await deps.validateRequest(request, { requireClubAdmin: clubId });
      if (isErrorResponse(validated)) return validated;

      const geminiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
      if (!geminiKey) {
        return jsonError("Image generation is not configured on the server.", 503);
      }

      const adminClient = deps.createAdminClient();
      const { data: club, error: clubError } = await adminClient
        .from("african_football_clubs")
        .select(
          "club_name, primary_brand_colors, nickname_brand_identity, country_name, region, league",
        )
        .eq("id", clubId)
        .single();

      if (clubError || !club) {
        return jsonError("Club not found.", 404);
      }

      const prompt = buildPrompt(club as ClubBrand, productType, productName);
      const geminiResponse = await deps.fetchFn(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              responseModalities: ["IMAGE", "TEXT"],
              temperature: 1.0,
            },
          }),
        },
      );

      if (!geminiResponse.ok) {
        const detail = await geminiResponse.text();
        return jsonError(
          `Gemini image generation failed: ${geminiResponse.status}`,
          502,
        );
      }

      const geminiBody = await geminiResponse.json() as GeminiImageResponse;
      const parts = geminiBody.candidates?.[0]?.content?.parts ?? [];
      const imagePart = parts.find((part) =>
        Object.hasOwn(part, "inlineData") || Object.hasOwn(part, "inline_data")
      );

      if (!imagePart) {
        return jsonError("Gemini did not return an image.", 502);
      }

      const inlineData = (imagePart.inlineData ?? imagePart.inline_data) as
        | Record<string, unknown>
        | undefined;
      const base64Data = asTrimmedString(inlineData?.["data"]);
      const mimeType = asTrimmedString(
        inlineData?.["mimeType"] ?? inlineData?.["mime_type"],
      ) ?? "image/png";

      if (!base64Data) {
        return jsonError("Gemini returned an invalid image payload.", 502);
      }

      const ext = mimeType.includes("jpeg") || mimeType.includes("jpg")
        ? "jpg"
        : "png";
      const slug = (club as ClubBrand).club_name.toLowerCase().replace(
        /[^a-z0-9]+/g,
        "-",
      );
      const storagePath = `${slug}/${productType}-${deps.randomId()}.${ext}`;
      const imageBytes = Uint8Array.from(
        atob(base64Data),
        (char) => char.charCodeAt(0),
      );

      const { error: uploadError } = await adminClient.storage
        .from("product-images")
        .upload(storagePath, imageBytes, {
          contentType: mimeType,
          upsert: true,
        });

      if (uploadError) {
        return jsonError(
          `Storage upload failed: ${uploadError.message}`,
          500,
        );
      }

      const { data: urlData } = adminClient.storage
        .from("product-images")
        .getPublicUrl(storagePath);
      const publicUrl = urlData.publicUrl;

      if (targetTable && targetId) {
        const { error: updateError } = await adminClient
          .from(targetTable)
          .update({
            image_url: publicUrl,
            image_prompt: prompt,
            updated_at: new Date().toISOString(),
          })
          .eq("id", targetId)
          .eq("club_id", clubId);

        if (updateError) {
          return jsonError(
            `Failed to update ${targetTable}: ${updateError.message}`,
            500,
          );
        }
      }

      return jsonOk({
        success: true,
        image_url: publicUrl,
        storage_path: storagePath,
        prompt_used: prompt,
        club: (club as ClubBrand).club_name,
        product_type: productType,
      });
    } catch (error) {
      console.error("generate-product-image failed:", error);
      return jsonError(
        error instanceof Error ? error.message : "Image generation failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createGenerateProductImageHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
