// The verdict of a render run. It lives apart from index.mjs, which starts a run when it is
// imported, so the tests can check the failure paths without a browser.

/**
 * The count check: the ids of the requested boards that have no PNG, in the order they were
 * requested, and the error line that names them (null when every board has its PNG).
 *
 * @param {Array<{id: string}>} targets the boards the run was asked for
 * @param {{has: (id: string) => boolean}} rendered the boards that kept their PNG
 * @returns {{missing: string[], error: string | null}}
 */
export function countCheck(targets, rendered) {
  const missing = targets.filter((t) => !rendered.has(t.id)).map((t) => t.id);
  const error =
    missing.length > 0 ? `NO PNG for ${missing.length} of ${targets.length} board(s): ${missing.join(' ')}` : null;
  return { missing, error };
}

/**
 * The exit code of a render run: 1 when a board failed, a PNG is missing (the count check), a
 * request was blocked, a file was missing from design/ or `--twice` found a difference; else 0.
 *
 * @param {{
 *   failures: unknown[],
 *   missing: string[],
 *   violations: unknown[],
 *   misses: string[],
 *   mismatches: unknown[],
 * }} run
 * @returns {0 | 1}
 */
export function runStatus({ failures, missing, violations, misses, mismatches }) {
  return failures.length + missing.length + violations.length + misses.length + mismatches.length > 0 ? 1 : 0;
}
