import {
  buildAndroidAssetLinks,
  createAssociationOptionsResponse,
  createAssociationResponse,
} from "@/lib/app-associations";

export const dynamic = "force-static";

export function GET() {
  return createAssociationResponse(buildAndroidAssetLinks());
}

export function HEAD() {
  return createAssociationResponse(buildAndroidAssetLinks(), { head: true });
}

export function OPTIONS() {
  return createAssociationOptionsResponse();
}
