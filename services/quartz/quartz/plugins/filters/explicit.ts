import { QuartzFilterPlugin } from "../types"

interface Options {
  /** Frontmatter key that marks a note as publishable when non-empty */
  classKey: string
  /** Tag that explicitly opts a note in to publishing */
  publishTag: string
  /** Tag that explicitly opts a note out of publishing (wins over class) */
  denyTag: string
}

const defaultOptions: Options = {
  classKey: "class",
  publishTag: "#notes",
  denyTag: "#lecture",
}

function isExplicitlyPublished(frontmatter: Record<string, unknown> | undefined): boolean {
  const publish = frontmatter?.["publish"]
  return publish === true || publish === "true"
}

function frontmatterTags(frontmatter: Record<string, unknown> | undefined): unknown[] {
  const value = frontmatter?.["tags"]
  if (Array.isArray(value)) return value
  if (typeof value === "string") return [value]
  return []
}

const normalizeTag = (tag: string): string => tag.trim().replace(/^#/, "").toLowerCase()

function tagListMatches(tags: unknown[], needle: string): boolean {
  const base = normalizeTag(needle)
  return tags.some((t) => {
    const plain = normalizeTag(String(t))
    return plain === base || plain.startsWith(`${base}/`)
  })
}

function textHasInlineTag(text: string | undefined, needle: string): boolean {
  if (!text) return false
  const base = normalizeTag(needle).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  return new RegExp(`#${base}(?:/[\\w\\-+%.]+)*(?=$|[\\s,|;#]|/)`, "i").test(text)
}

function hasDenyTag(frontmatter: Record<string, unknown> | undefined, text: string | undefined, tag: string): boolean {
  return tagListMatches(frontmatterTags(frontmatter), tag) || textHasInlineTag(text, tag)
}

function hasPublishTag(frontmatter: Record<string, unknown> | undefined, text: string | undefined, tag: string): boolean {
  return tagListMatches(frontmatterTags(frontmatter), tag) || textHasInlineTag(text, tag)
}

function hasNonEmptyClass(frontmatter: Record<string, unknown> | undefined, key: string): boolean {
  const value = frontmatter?.[key]
  if (value === undefined || value === null) return false
  if (Array.isArray(value)) {
    return value.some((entry) => typeof entry === "string" && entry.trim().length > 0)
  }
  return typeof value === "string" && value.trim().length > 0
}

/**
 * Publish rules (first rule that matches wins):
 *  1. `publish: true`  — always publish.
 *  2. root `index.md`   — global home page, always publish.
 *  3. `#lecture` tag    — always private (deny overrides class).
 *  4. `#notes` tag      — always publish.
 *  5. non-empty `class` — publish (e.g. a course's whatever.md).
 */
export const ExplicitPublish: QuartzFilterPlugin<Partial<Options>> = (userOpts) => {
  const opts = { ...defaultOptions, ...userOpts }
  return {
    name: "ExplicitPublish",
    shouldPublish(_ctx, [_tree, vfile]) {
      const fm = vfile.data?.frontmatter as Record<string, unknown> | undefined
      const text = (vfile.data?.text as string | undefined) ?? ""
      if (isExplicitlyPublished(fm)) return true
      if (vfile.data?.slug === "index") return true
      if (hasDenyTag(fm, text, opts.denyTag)) return false
      if (hasPublishTag(fm, text, opts.publishTag)) return true
      return hasNonEmptyClass(fm, opts.classKey)
    },
  }
}