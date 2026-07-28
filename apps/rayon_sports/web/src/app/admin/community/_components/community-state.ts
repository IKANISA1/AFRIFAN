export type CommunityForm = {
  id: string;
  expectedUpdatedAt: string;
  name: string;
  region: string;
  description: string;
  memberCount: string;
  eventCount: string;
  rating: string;
  bannerImageUrl: string;
  isActive: boolean;
};

export const emptyForm: CommunityForm = {
  id: "",
  expectedUpdatedAt: "",
  name: "",
  region: "",
  description: "",
  memberCount: "0",
  eventCount: "0",
  rating: "0",
  bannerImageUrl: "",
  isActive: true,
};
