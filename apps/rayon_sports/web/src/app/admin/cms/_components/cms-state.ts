export type ArticleForm = {
  id: string;
  title: string;
  subtitle: string;
  category: string;
  excerpt: string;
  body: string;
  imageUrl: string;
  isPublished: boolean;
  isFeatured: boolean;
};

export const emptyArticleForm: ArticleForm = {
  id: "",
  title: "",
  subtitle: "",
  category: "News",
  excerpt: "",
  body: "",
  imageUrl: "",
  isPublished: false,
  isFeatured: false,
};

export function wordCount(text: string) {
  return text.trim() ? text.trim().split(/\s+/).length : 0;
}
