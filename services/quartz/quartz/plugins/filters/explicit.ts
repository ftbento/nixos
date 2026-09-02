import { QuartzFilterPlugin } from "../types"

interface Options {
  /** Frontmatter key that marks a note as publishable when non-empty */
  classKey: string
}

const defaultOptions: Options = {
  classKey: "class",
}

function isExplicitlyPublished(frontmatter: Record<string, unknown> | undefined): boolean {
  const publish = frontmatter?.["publish"]
  return publish === true || publish === "true"
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
 * Publish a note when it opts in via `publish: true` OR carries a non-empty
 * `class` frontmatter property (e.g. `class: "COT 3100C - Introduction to
 * Discrete Structures"`). Everything else stays private.
 */
export const ExplicitPublish: QuartzFilterPlugin<Partial<Options>> = (userOpts) => {
  const opts = { ...defaultOptions, ...userOpts }
  return {
    name: "ExplicitPublish",
    shouldPublish(_ctx, [_tree, vfile]) {
      const fm = vfile.data?.frontmatter as Record<string, unknown> | undefined
      return vfile.data?.slug === "index" || isExplicitlyPublished(fm) || hasNonEmptyClass(fm, opts.classKey)
    },
  }
}