import {
  buildAppleAppSiteAssociation,
  createAssociationOptionsResponse,
  createAssociationResponse,
} from "@/lib/app-associations";

export const dynamic = "force-static";

export function GET() {
  return createAssociationResponse(buildAppleAppSiteAssociation());
}

export function HEAD() {
  return createAssociationResponse(buildAppleAppSiteAssociation(), {
    head: true,
  });
}

export function OPTIONS() {
  return createAssociationOptionsResponse();
}
