/**
 * Web Share API helpers.
 *
 * Allows admin users to share match results, CMS articles,
 * and other content natively via the OS share sheet.
 */
import { siteConfig } from "@/lib/config";

export interface ShareData {
  title: string;
  text?: string;
  url: string;
}

/**
 * Check if the Web Share API is available.
 */
export function isShareSupported(): boolean {
  return typeof navigator !== "undefined" && "share" in navigator;
}

/**
 * Check if the Web Share API supports sharing files.
 */
export function isFileShareSupported(): boolean {
  return isShareSupported() && "canShare" in navigator;
}

/**
 * Share content via the native OS share sheet.
 *
 * Falls back to clipboard copy if Web Share is not available.
 * Returns true if content was shared successfully.
 */
export async function shareContent(data: ShareData): Promise<boolean> {
  if (isShareSupported()) {
    try {
      await navigator.share({
        title: data.title,
        text: data.text,
        url: data.url,
      });
      return true;
    } catch (error) {
      // User cancelled or share failed
      if (error instanceof Error && error.name === "AbortError") {
        return false; // User cancelled — not an error
      }
      console.warn("[share] Web Share failed, falling back to clipboard:", error);
    }
  }

  // Fallback: copy URL to clipboard
  return copyToClipboard(data.url);
}

/**
 * Share a match result.
 */
export function shareMatchResult(
  homeTeam: string,
  awayTeam: string,
  score: string,
  matchUrl: string,
): Promise<boolean> {
  return shareContent({
    title: `${homeTeam} vs ${awayTeam}`,
    text: `${homeTeam} ${score} ${awayTeam} — ${siteConfig.shortTitle}`,
    url: matchUrl,
  });
}

/**
 * Share a CMS article.
 */
export function shareArticle(
  title: string,
  excerpt: string,
  articleUrl: string,
): Promise<boolean> {
  return shareContent({
    title,
    text: excerpt,
    url: articleUrl,
  });
}

/**
 * Copy text to clipboard (fallback for Web Share).
 */
async function copyToClipboard(text: string): Promise<boolean> {
  try {
    if ("clipboard" in navigator) {
      await navigator.clipboard.writeText(text);
      return true;
    }

    // Legacy fallback
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
    return true;
  } catch {
    return false;
  }
}
