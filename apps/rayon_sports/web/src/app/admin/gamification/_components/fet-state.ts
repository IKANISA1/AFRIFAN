import type {
  AdminFanEngagementTemplateScope,
  AdminFanEngagementToken,
} from "@/lib/types";

export const scopeColors: Record<AdminFanEngagementTemplateScope, string> = {
  generic: "admin-fet-scope-generic",
  club_specific: "admin-fet-scope-club",
};

export type FetForm = {
  id: string;
  expectedUpdatedAt: string;
  code: string;
  templateScope: AdminFanEngagementTemplateScope;
  category: string;
  itemName: string;
  fetValue: string;
  triggerCondition: string;
  activationTiming: string;
  description: string;
  badgeName: string;
  implementationNotes: string;
  sortOrder: string;
  isActive: boolean;
};

export const emptyFetForm: FetForm = {
  id: "",
  expectedUpdatedAt: "",
  code: "",
  templateScope: "generic",
  category: "",
  itemName: "",
  fetValue: "100",
  triggerCondition: "",
  activationTiming: "",
  description: "",
  badgeName: "",
  implementationNotes: "",
  sortOrder: "0",
  isActive: true,
};

export function tokenToForm(token: AdminFanEngagementToken): FetForm {
  return {
    id: token.id,
    expectedUpdatedAt: token.updatedAt,
    code: token.code,
    templateScope: token.templateScope,
    category: token.category,
    itemName: token.itemName,
    fetValue: token.fetValue.toString(),
    triggerCondition: token.triggerCondition,
    activationTiming: token.activationTiming,
    description: token.description,
    badgeName: token.badgeName,
    implementationNotes: token.implementationNotes ?? "",
    sortOrder: token.sortOrder.toString(),
    isActive: token.isActive,
  };
}
