import { tool, type Plugin } from "@opencode-ai/plugin";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, mkdir, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const execFileAsync = promisify(execFile);

type LookupStatus = "ok" | "error";

type LookupError = {
  code: string;
  message: string;
  details?: Record<string, unknown>;
};

type LookupAction = {
  type: string;
  args?: Record<string, unknown>;
  reason?: string;
};

type LookupHit = {
  path: string;
  line: number;
  snippet: string;
  score: number;
  confidence: number;
  reasons: string[];
};

type LookupResult = {
  status: LookupStatus;
  source: {
    ecosystem: string;
    package_name: string;
    package_spec: string;
    repository_url?: string;
    host?: string;
  };
  resolved_ref?: {
    label: string;
    commit: string;
    ref_source: string;
    normalized_ref: string;
  };
  hits: LookupHit[];
  next_actions: LookupAction[];
  errors: LookupError[];
};

type ParsedLookupSpec = {
  ecosystem: "npm" | "git";
  target: string;
};

type ParsedNpmPackageSpec = {
  name: string;
  requested_spec?: string;
};

type ParsedGitRepositorySpec = {
  repository_path: string;
  requested_ref?: string;
  parsed_repo: ParsedRepository;
};

type ParsedRepository = {
  clone_url: string;
  host: string;
};

type ResolvedTarget = {
  label: string;
  commit: string;
  ref_source: string;
};

type Semver = {
  major: number;
  minor: number;
  patch: number;
  prerelease: Array<number | string>;
};

const LibraryContextPlugin: Plugin = async () => {
  return {
    tool: {
      library_code_lookup: tool({
        description:
          "Clone and inspect package or repository source to return ranked source-based results.",
        args: {
          package_name: tool.schema.string().min(1),
          query: tool.schema.string().min(1),
          ecosystem: tool.schema.string().optional(),
          max_hits: tool.schema.number().int().min(1).max(25).default(8),
        },
        async execute(args, context) {
          context.metadata({
            title: `Library source lookup: ${args.package_name}`,
            metadata: { query: args.query, package_spec: args.package_name },
          });

          try {
            const result = await lookupLibrarySource({
              directory: context.directory,
              packageSpec: args.package_name,
              query: args.query,
              legacyEcosystem: args.ecosystem,
              maxHits: args.max_hits,
            });
            return JSON.stringify(result, null, 2);
          } catch (error) {
            return JSON.stringify(
              {
                status: "error",
                source: {
                  ecosystem: "unknown",
                  package_name: args.package_name,
                  package_spec: args.package_name,
                },
                hits: [],
                next_actions: [],
                errors: [
                  {
                    code: "unexpected_failure",
                    message: "Unhandled error during lookup",
                    details: {
                      error:
                        error instanceof Error ? error.message : String(error),
                    },
                  },
                ],
              } satisfies LookupResult,
              null,
              2,
            );
          }
        },
      }),
    },
  };
};

export default LibraryContextPlugin;

async function lookupLibrarySource(input: {
  directory: string;
  packageSpec: string;
  query: string;
  legacyEcosystem?: string;
  maxHits: number;
}): Promise<LookupResult> {
  if (input.legacyEcosystem !== undefined) {
    return errorResult({
      ecosystem: "unknown",
      packageName: input.packageSpec,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "invalid_contract",
          message:
            "Argument 'ecosystem' is no longer accepted. Use explicit package_name spec like 'npm:react@18' or 'git:sveltejs/kit'.",
        },
      ],
    });
  }

  let parsedLookupSpec: ParsedLookupSpec;

  try {
    parsedLookupSpec = parseLookupSpec(input.packageSpec);
  } catch (error) {
    return errorResult({
      ecosystem: "unknown",
      packageName: input.packageSpec,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "invalid_spec",
          message:
            error instanceof Error
              ? error.message
              : "Invalid package_name spec",
          details: {
            examples: [
              "npm:react@18",
              "npm:@types/node@20",
              "git:sveltejs/kit",
            ],
          },
        },
      ],
    });
  }

  if (parsedLookupSpec.ecosystem === "npm") {
    return lookupNpmSource({
      directory: input.directory,
      packageTarget: parsedLookupSpec.target,
      packageSpec: input.packageSpec,
      query: input.query,
      maxHits: input.maxHits,
    });
  }

  return lookupGitSource({
    packageTarget: parsedLookupSpec.target,
    packageSpec: input.packageSpec,
    query: input.query,
    maxHits: input.maxHits,
  });
}

async function lookupNpmSource(input: {
  directory: string;
  packageTarget: string;
  packageSpec: string;
  query: string;
  maxHits: number;
}): Promise<LookupResult> {
  const parsedSpec = parseNpmPackageSpec(input.packageTarget);

  if (!parsedSpec.name.trim()) {
    return errorResult({
      ecosystem: "npm",
      packageName: input.packageTarget,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "invalid_spec",
          message: "Invalid npm package name in package_name spec",
          details: {
            examples: ["npm:react@18", "npm:@types/node@20"],
          },
        },
      ],
    });
  }

  let metadata: any;

  try {
    metadata = await fetchNpmMetadata(parsedSpec.name);
  } catch (error) {
    return errorResult({
      ecosystem: "npm",
      packageName: parsedSpec.name,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "npm_lookup_failed",
          message: "Failed to load npm metadata",
          details: {
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
    });
  }

  const projectVersion = await resolveProjectVersion(
    input.directory,
    parsedSpec.name,
    metadata,
  );
  const requestedVersion = resolveSpecVersion(
    parsedSpec.requested_spec,
    metadata,
  );

  const repositorySourceVersion =
    projectVersion?.version ??
    requestedVersion ??
    metadata["dist-tags"]?.latest;
  const repositoryURLRaw = extractRepositoryURL(
    metadata,
    repositorySourceVersion,
  );

  if (!repositoryURLRaw) {
    return errorResult({
      ecosystem: "npm",
      packageName: parsedSpec.name,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "repository_not_found",
          message:
            "Could not resolve repository URL from npm metadata. Provide explicit repository URL in the parent flow.",
        },
      ],
    });
  }

  let parsedRepo: ParsedRepository;

  try {
    parsedRepo = parseRepositoryURL(repositoryURLRaw);
  } catch (error) {
    return errorResult({
      ecosystem: "npm",
      packageName: parsedSpec.name,
      packageSpec: input.packageSpec,
      repositoryURL: repositoryURLRaw,
      errors: [
        {
          code: "invalid_repository_url",
          message: "Repository URL is invalid or unsupported",
          details: {
            repository_url: repositoryURLRaw,
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
    });
  }

  let refs: {
    tags: Array<{ name: string; commit: string }>;
    heads: Array<{ name: string; commit: string }>;
    default_branch?: string;
  };

  try {
    refs = await listRemoteRefs(parsedRepo.clone_url);
  } catch (error) {
    return errorResult({
      ecosystem: "npm",
      packageName: parsedSpec.name,
      packageSpec: input.packageSpec,
      repositoryURL: parsedRepo.clone_url,
      host: parsedRepo.host,
      errors: [
        {
          code: "git_refs_failed",
          message: "Failed to list repository refs",
          details: {
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
    });
  }

  const target = resolveLookupTarget({
    refs,
    projectVersion,
    requestedVersion,
  });

  return lookupRepositorySource({
    query: input.query,
    maxHits: input.maxHits,
    ecosystem: "npm",
    packageName: parsedSpec.name,
    packageSpec: input.packageSpec,
    parsedRepo,
    target,
    targetFailureMessage:
      "Could not resolve a matching tag or default branch from repository refs.",
  });
}

async function lookupGitSource(input: {
  packageTarget: string;
  packageSpec: string;
  query: string;
  maxHits: number;
}): Promise<LookupResult> {
  let parsedSpec: ParsedGitRepositorySpec;

  try {
    parsedSpec = parseGitRepositorySpec(input.packageTarget);
  } catch (error) {
    return errorResult({
      ecosystem: "git",
      packageName: input.packageTarget,
      packageSpec: input.packageSpec,
      errors: [
        {
          code: "invalid_spec",
          message:
            error instanceof Error
              ? error.message
              : "Invalid git repository spec",
          details: {
            examples: ["git:sveltejs/kit", "git:sveltejs/kit@main"],
          },
        },
      ],
    });
  }

  let refs: {
    tags: Array<{ name: string; commit: string }>;
    heads: Array<{ name: string; commit: string }>;
    default_branch?: string;
  };

  try {
    refs = await listRemoteRefs(parsedSpec.parsed_repo.clone_url);
  } catch (error) {
    return errorResult({
      ecosystem: "git",
      packageName: parsedSpec.repository_path,
      packageSpec: input.packageSpec,
      repositoryURL: parsedSpec.parsed_repo.clone_url,
      host: parsedSpec.parsed_repo.host,
      errors: [
        {
          code: "git_refs_failed",
          message: "Failed to list repository refs",
          details: {
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
    });
  }

  let target: ResolvedTarget | null;

  if (parsedSpec.requested_ref) {
    target = resolveRequestedLookupTarget(refs, parsedSpec.requested_ref);
    if (!target) {
      return errorResult({
        ecosystem: "git",
        packageName: parsedSpec.repository_path,
        packageSpec: input.packageSpec,
        repositoryURL: parsedSpec.parsed_repo.clone_url,
        host: parsedSpec.parsed_repo.host,
        errors: [
          {
            code: "no_resolvable_ref",
            message: `Could not resolve requested ref '${parsedSpec.requested_ref}' from repository refs.`,
          },
        ],
      });
    }
  } else {
    target = resolveLookupTarget({
      refs,
      projectVersion: null,
      requestedVersion: null,
    });
  }

  return lookupRepositorySource({
    query: input.query,
    maxHits: input.maxHits,
    ecosystem: "git",
    packageName: parsedSpec.repository_path,
    packageSpec: input.packageSpec,
    parsedRepo: parsedSpec.parsed_repo,
    target,
    targetFailureMessage:
      "Could not resolve default branch or a semver tag from repository refs.",
  });
}

async function lookupRepositorySource(input: {
  query: string;
  maxHits: number;
  ecosystem: string;
  packageName: string;
  packageSpec: string;
  parsedRepo: ParsedRepository;
  target: ResolvedTarget | null;
  targetFailureMessage: string;
}): Promise<LookupResult> {
  if (!input.target) {
    return errorResult({
      ecosystem: input.ecosystem,
      packageName: input.packageName,
      packageSpec: input.packageSpec,
      repositoryURL: input.parsedRepo.clone_url,
      host: input.parsedRepo.host,
      errors: [
        {
          code: "no_resolvable_ref",
          message: input.targetFailureMessage,
        },
      ],
    });
  }

  const tempRoot = await mkdtemp(
    path.join(tmpdir(), "opencode-library-context-"),
  );
  const repoDirectory = path.join(tempRoot, "repo");

  try {
    await checkoutCommitRef(
      repoDirectory,
      input.parsedRepo.clone_url,
      input.target.commit,
    );

    const search = await searchCodebase(
      repoDirectory,
      input.query,
      input.maxHits,
    );
    const nextActions: LookupAction[] = [];
    const seenPaths = new Set<string>();

    for (const hit of search.hits) {
      if (seenPaths.has(hit.path)) continue;
      seenPaths.add(hit.path);
      nextActions.push({
        type: "read_file",
        args: { path: hit.path },
        reason: "Inspect this ranked hit for concrete usage/API details",
      });
      if (nextActions.length >= 3) break;
    }

    if (search.hits.length === 0) {
      nextActions.push({
        type: "refine_query",
        args: { suggestion: "Use symbols, function names, or API identifiers" },
        reason: "No matching source hits found",
      });
    }

    return {
      status: "ok",
      source: {
        ecosystem: input.ecosystem,
        package_name: input.packageName,
        package_spec: input.packageSpec,
        repository_url: input.parsedRepo.clone_url,
        host: input.parsedRepo.host,
      },
      resolved_ref: {
        label: input.target.label,
        commit: input.target.commit,
        ref_source: input.target.ref_source,
        normalized_ref: buildRefKey(input.target.label, input.target.commit),
      },
      hits: search.hits,
      next_actions: nextActions,
      errors: search.errors,
    };
  } finally {
    await rm(tempRoot, { recursive: true, force: true });
  }
}

function parseLookupSpec(input: string): ParsedLookupSpec {
  const spec = input.trim();
  const separator = spec.indexOf(":");

  if (separator <= 0) {
    throw new Error(
      "package_name must use explicit '<ecosystem>:<target>' format, e.g. 'npm:react@18' or 'git:sveltejs/kit'.",
    );
  }

  const ecosystemRaw = spec.slice(0, separator).trim().toLowerCase();
  const target = spec.slice(separator + 1).trim();

  if (!target) {
    throw new Error("Lookup target is missing after ecosystem prefix.");
  }

  if (ecosystemRaw !== "npm" && ecosystemRaw !== "git") {
    throw new Error(
      `Unsupported ecosystem '${ecosystemRaw}'. Supported ecosystems: npm, git.`,
    );
  }

  return {
    ecosystem: ecosystemRaw as "npm" | "git",
    target,
  };
}

function parseNpmPackageSpec(input: string): ParsedNpmPackageSpec {
  const spec = input.trim();
  if (spec.length === 0) {
    return { name: input };
  }

  if (spec.startsWith("@")) {
    const index = spec.indexOf("@", 1);
    if (index === -1) return { name: spec };
    return {
      name: spec.slice(0, index),
      requested_spec: spec.slice(index + 1).trim() || undefined,
    };
  }

  const index = spec.indexOf("@");
  if (index === -1) return { name: spec };

  return {
    name: spec.slice(0, index),
    requested_spec: spec.slice(index + 1).trim() || undefined,
  };
}

function parseGitRepositorySpec(input: string): ParsedGitRepositorySpec {
  const value = input.trim();
  if (!value) {
    throw new Error("Git repository target cannot be empty.");
  }

  const separator = value.lastIndexOf("@");
  const repositoryPath = (
    separator > 0 ? value.slice(0, separator) : value
  ).trim();
  const requestedRef =
    separator > 0 ? value.slice(separator + 1).trim() || undefined : undefined;

  if (!/^[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)+$/.test(repositoryPath)) {
    throw new Error(
      "Git target must be a repository path like 'owner/repo' or 'owner/repo@ref'.",
    );
  }

  const parsedRepo = parseRepositoryURL(
    `https://github.com/${repositoryPath}.git`,
  );

  return {
    repository_path: repositoryPath,
    requested_ref: requestedRef,
    parsed_repo: parsedRepo,
  };
}

async function fetchNpmMetadata(packageName: string): Promise<any> {
  const response = await fetch(
    `https://registry.npmjs.org/${encodeURIComponent(packageName)}`,
    {
      headers: { accept: "application/json" },
    },
  );

  if (!response.ok) {
    throw new Error(`npm metadata lookup failed (${response.status})`);
  }

  return response.json();
}

function extractRepositoryURL(metadata: any, version?: string): string | null {
  const candidates: any[] = [];

  if (version && metadata?.versions?.[version]?.repository) {
    candidates.push(metadata.versions[version].repository);
  }

  if (metadata?.repository) {
    candidates.push(metadata.repository);
  }

  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim().length > 0) {
      return candidate.trim();
    }

    if (
      candidate &&
      typeof candidate === "object" &&
      typeof candidate.url === "string" &&
      candidate.url.trim().length > 0
    ) {
      return candidate.url.trim();
    }
  }

  return null;
}

function parseRepositoryURL(input: string): ParsedRepository {
  let value = input.trim();

  if (value.startsWith("git+")) value = value.slice(4);
  if (value.startsWith("git://")) value = `https://${value.slice(6)}`;
  if (value.startsWith("ssh://git@")) {
    value = value.replace(/^ssh:\/\/git@([^/]+)\//, "https://$1/");
  }
  if (/^git@[^:]+:.+/.test(value)) {
    value = value.replace(/^git@([^:]+):/, "https://$1/");
  }

  value = value.replace(/#.*$/, "");

  if (!/^https?:\/\//i.test(value)) {
    throw new Error("Repository URL must be HTTP(S)-compatible");
  }

  const parsed = new URL(value);
  const host = normalizeHost(parsed.host);
  const segments = parsed.pathname
    .replace(/^\/+|\/+$/g, "")
    .split("/")
    .filter(Boolean);

  if (segments.length < 2) {
    throw new Error("Repository URL must include owner and repo path");
  }

  const repo = segments.at(-1)?.replace(/\.git$/i, "") ?? "";
  const ownerSegments = segments.slice(0, -1);

  if (!repo || ownerSegments.length === 0) {
    throw new Error("Could not parse owner/repo from repository URL");
  }

  return {
    clone_url: `https://${host}/${[...ownerSegments, repo].join("/")}.git`,
    host,
  };
}

async function resolveProjectVersion(
  directory: string,
  packageName: string,
  metadata: any,
): Promise<{ version: string; source: string } | null> {
  const packageLock = await findVersionInPackageLock(directory, packageName);
  if (packageLock && metadata?.versions?.[packageLock]) {
    return { version: packageLock, source: "project_lockfile" };
  }

  const pnpmLock = await findVersionInPnpmLock(directory, packageName);
  if (pnpmLock && metadata?.versions?.[pnpmLock]) {
    return { version: pnpmLock, source: "project_lockfile" };
  }

  const yarnLock = await findVersionInYarnLock(directory, packageName);
  if (yarnLock && metadata?.versions?.[yarnLock]) {
    return { version: yarnLock, source: "project_lockfile" };
  }

  const packageJSONSpec = await findSpecInPackageJSON(directory, packageName);
  if (!packageJSONSpec) return null;

  const resolved = resolveSpecVersion(packageJSONSpec, metadata);
  if (!resolved) return null;

  return { version: resolved, source: "project_package_spec" };
}

async function findVersionInPackageLock(
  directory: string,
  packageName: string,
): Promise<string | null> {
  const filePath = path.join(directory, "package-lock.json");
  if (!(await pathExists(filePath))) return null;

  try {
    const parsed = JSON.parse(await readFile(filePath, "utf8"));
    const fromPackages =
      parsed?.packages?.[`node_modules/${packageName}`]?.version;
    if (typeof fromPackages === "string") return fromPackages;

    const fromDependencies = parsed?.dependencies?.[packageName]?.version;
    if (typeof fromDependencies === "string") return fromDependencies;
  } catch {
    return null;
  }

  return null;
}

async function findVersionInPnpmLock(
  directory: string,
  packageName: string,
): Promise<string | null> {
  const filePath = path.join(directory, "pnpm-lock.yaml");
  if (!(await pathExists(filePath))) return null;

  try {
    const content = await readFile(filePath, "utf8");
    const escaped = escapeRegex(packageName);
    const patterns = [
      new RegExp(`(?:^|\\n)\\s*\\/${escaped}@([^:\\s(]+)`, "m"),
      new RegExp(`(?:^|\\n)\\s*${escaped}@([^:\\s(]+):`, "m"),
    ];

    for (const pattern of patterns) {
      const match = content.match(pattern);
      if (match?.[1]) return sanitizeVersion(match[1]);
    }
  } catch {
    return null;
  }

  return null;
}

async function findVersionInYarnLock(
  directory: string,
  packageName: string,
): Promise<string | null> {
  const filePath = path.join(directory, "yarn.lock");
  if (!(await pathExists(filePath))) return null;

  try {
    const content = await readFile(filePath, "utf8");
    const sections = content.split(/\n{2,}/g);

    for (const section of sections) {
      if (!section.includes(`${packageName}@`)) continue;
      const match = section.match(/\n\s*version\s+"([^"]+)"/);
      if (match?.[1]) return sanitizeVersion(match[1]);
    }
  } catch {
    return null;
  }

  return null;
}

async function findSpecInPackageJSON(
  directory: string,
  packageName: string,
): Promise<string | null> {
  const filePath = path.join(directory, "package.json");
  if (!(await pathExists(filePath))) return null;

  try {
    const pkg = JSON.parse(await readFile(filePath, "utf8"));
    const fields = [
      "dependencies",
      "devDependencies",
      "peerDependencies",
      "optionalDependencies",
      "resolutions",
      "overrides",
    ];

    for (const field of fields) {
      const value = pkg?.[field]?.[packageName];
      if (typeof value === "string" && value.trim()) return value.trim();
    }
  } catch {
    return null;
  }

  return null;
}

function resolveSpecVersion(
  spec: string | undefined,
  metadata: any,
): string | null {
  if (!spec) return null;

  const cleaned = normalizeNpmSpec(spec);
  if (!cleaned) return null;

  const versions = Object.keys(metadata?.versions ?? {});
  if (versions.length === 0) return null;

  const distTags = metadata?.["dist-tags"] ?? {};
  if (typeof distTags[cleaned] === "string") {
    return distTags[cleaned];
  }

  if (metadata?.versions?.[cleaned]) {
    return cleaned;
  }

  const sorted = versions
    .filter((version) => parseSemver(version) !== null)
    .sort((a, b) => compareSemverStrings(b, a));

  for (const version of sorted) {
    if (satisfiesRange(version, cleaned)) {
      return version;
    }
  }

  return null;
}

function normalizeNpmSpec(input: string): string {
  let value = input.trim();
  value = value.replace(/^workspace:/, "");
  value = value.replace(/^npm:/, "");
  return value.trim();
}

async function listRemoteRefs(repoURL: string): Promise<{
  tags: Array<{ name: string; commit: string }>;
  heads: Array<{ name: string; commit: string }>;
  default_branch?: string;
}> {
  const refsOutput = await runGit([
    "ls-remote",
    "--refs",
    "--heads",
    "--tags",
    repoURL,
  ]);
  const symrefOutput = await runGit(["ls-remote", "--symref", repoURL, "HEAD"]);

  const tags: Array<{ name: string; commit: string }> = [];
  const heads: Array<{ name: string; commit: string }> = [];

  for (const line of refsOutput.split("\n")) {
    if (!line.trim()) continue;
    const [commit, ref] = line.trim().split(/\s+/);
    if (!commit || !ref) continue;

    if (ref.startsWith("refs/tags/")) {
      tags.push({ name: ref.slice("refs/tags/".length), commit });
      continue;
    }

    if (ref.startsWith("refs/heads/")) {
      heads.push({ name: ref.slice("refs/heads/".length), commit });
    }
  }

  let defaultBranch: string | undefined;

  for (const line of symrefOutput.split("\n")) {
    if (!line.startsWith("ref:")) continue;
    const match = line.match(/^ref:\s+refs\/heads\/([^\s]+)\s+HEAD$/);
    if (match?.[1]) {
      defaultBranch = match[1];
      break;
    }
  }

  return { tags, heads, default_branch: defaultBranch };
}

function resolveLookupTarget(input: {
  refs: {
    tags: Array<{ name: string; commit: string }>;
    heads: Array<{ name: string; commit: string }>;
    default_branch?: string;
  };
  projectVersion: { version: string; source: string } | null;
  requestedVersion: string | null;
}): ResolvedTarget | null {
  if (input.projectVersion) {
    const fromProject = findTagForVersion(
      input.refs.tags,
      input.projectVersion.version,
    );
    if (fromProject) {
      return {
        label: fromProject.name,
        commit: fromProject.commit,
        ref_source: input.projectVersion.source,
      };
    }
  }

  if (input.requestedVersion) {
    const fromRequested = findTagForVersion(
      input.refs.tags,
      input.requestedVersion,
    );
    if (fromRequested) {
      return {
        label: fromRequested.name,
        commit: fromRequested.commit,
        ref_source: "requested_spec",
      };
    }
  }

  const latestTag = findLatestSemverTag(input.refs.tags);
  if (latestTag) {
    return {
      label: latestTag.name,
      commit: latestTag.commit,
      ref_source: "latest_tag",
    };
  }

  const branchName =
    input.refs.default_branch ??
    findHead(input.refs.heads, "main")?.name ??
    findHead(input.refs.heads, "master")?.name;

  if (!branchName) return null;

  const branch = findHead(input.refs.heads, branchName);
  if (!branch) return null;

  return {
    label: branch.name,
    commit: branch.commit,
    ref_source: "default_branch",
  };
}

function resolveRequestedLookupTarget(
  refs: {
    tags: Array<{ name: string; commit: string }>;
    heads: Array<{ name: string; commit: string }>;
  },
  requestedRef: string,
): ResolvedTarget | null {
  const normalized = requestedRef.trim();
  if (!normalized) return null;

  const tagName = normalized.replace(/^refs\/tags\//, "");
  const headName = normalized.replace(/^refs\/heads\//, "");

  const fromTag =
    findTagForVersion(refs.tags, tagName) ??
    refs.tags.find((tag) => tag.name === tagName) ??
    null;
  if (fromTag) {
    return {
      label: fromTag.name,
      commit: fromTag.commit,
      ref_source: "requested_spec",
    };
  }

  const fromHead = findHead(refs.heads, headName);
  if (fromHead) {
    return {
      label: fromHead.name,
      commit: fromHead.commit,
      ref_source: "requested_spec",
    };
  }

  const commitNeedle = normalized.toLowerCase();
  const fromCommit = [...refs.tags, ...refs.heads].find((ref) =>
    ref.commit.toLowerCase().startsWith(commitNeedle),
  );

  if (fromCommit) {
    return {
      label: normalized,
      commit: fromCommit.commit,
      ref_source: "requested_spec",
    };
  }

  return null;
}

function findTagForVersion(
  tags: Array<{ name: string; commit: string }>,
  version: string,
): { name: string; commit: string } | null {
  const candidates = new Set([version, `v${version}`]);

  for (const tag of tags) {
    if (candidates.has(tag.name)) return tag;
  }

  return null;
}

function findLatestSemverTag(
  tags: Array<{ name: string; commit: string }>,
): { name: string; commit: string } | null {
  const parsed = tags
    .map((tag) => ({
      tag,
      semver: parseSemver(stripTagPrefix(tag.name)),
    }))
    .filter(
      (
        item,
      ): item is { tag: { name: string; commit: string }; semver: Semver } =>
        Boolean(item.semver),
    );

  if (parsed.length === 0) return null;

  parsed.sort((a, b) => compareSemver(b.semver, a.semver));
  return parsed[0]?.tag ?? null;
}

function findHead(
  heads: Array<{ name: string; commit: string }>,
  name: string,
): { name: string; commit: string } | null {
  return heads.find((head) => head.name === name) ?? null;
}

async function checkoutCommitRef(
  directory: string,
  repoURL: string,
  commit: string,
): Promise<void> {
  await mkdir(directory, { recursive: true });

  await runGit(["init"], directory);
  await runGit(["remote", "add", "origin", repoURL], directory);
  await runGit(["fetch", "--depth", "1", "origin", commit], directory);
  await runGit(["checkout", "--detach", "--force", "FETCH_HEAD"], directory);
}

async function searchCodebase(
  root: string,
  query: string,
  maxHits: number,
): Promise<{ hits: LookupHit[]; errors: LookupError[] }> {
  const terms = tokenizeQuery(query);
  const pattern =
    terms.length > 0 ? terms.map(escapeRegex).join("|") : escapeRegex(query);

  const rgResult = await safeExec(
    "rg",
    [
      "--json",
      "--line-number",
      "--hidden",
      "--max-filesize",
      "1M",
      "--glob",
      "!.git/*",
      "--glob",
      "!**/node_modules/**",
      "--glob",
      "!**/dist/**",
      "--glob",
      "!**/build/**",
      "--glob",
      "!**/*.min.*",
      "-e",
      pattern,
      ".",
    ],
    root,
  );

  if (!rgResult.ok && rgResult.exitCode !== 1) {
    return {
      hits: [],
      errors: [
        {
          code: "search_failed",
          message: "ripgrep execution failed",
          details: {
            exit_code: rgResult.exitCode,
            stderr: rgResult.stderr.trim() || "unknown",
          },
        },
      ],
    };
  }

  const hits: LookupHit[] = [];
  const seen = new Set<string>();

  for (const line of rgResult.stdout.split("\n")) {
    if (!line.trim()) continue;

    let payload: any;
    try {
      payload = JSON.parse(line);
    } catch {
      continue;
    }

    if (payload?.type !== "match") continue;

    const relPath = payload?.data?.path?.text as string | undefined;
    const lineNumber = payload?.data?.line_number as number | undefined;
    const snippet = payload?.data?.lines?.text as string | undefined;

    if (
      !relPath ||
      typeof lineNumber !== "number" ||
      typeof snippet !== "string"
    ) {
      continue;
    }

    if (isBinaryByExtension(relPath)) continue;

    const key = `${relPath}:${lineNumber}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const ranked = rankHit(relPath, lineNumber, snippet, terms);
    hits.push(ranked);
  }

  hits.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (a.path !== b.path) return a.path.localeCompare(b.path);
    return a.line - b.line;
  });

  return {
    hits: hits.slice(0, maxHits),
    errors: [],
  };
}

function rankHit(
  relPath: string,
  lineNumber: number,
  snippetRaw: string,
  terms: string[],
): LookupHit {
  const pathLower = relPath.toLowerCase();
  const snippet = snippetRaw.trim().slice(0, 240);
  const snippetLower = snippet.toLowerCase();
  const reasons: string[] = [];

  let score = 1;

  if (/(^|\/)(examples?|demo|sample|playground)(\/|$)/.test(pathLower)) {
    score += 8;
    reasons.push("example_usage");
  }

  if (/\bexport\b|module\.exports|exports\./.test(snippet)) {
    score += 6;
    reasons.push("public_api");
  }

  if (/(^|\/)src\//.test(pathLower)) {
    score += 3;
    reasons.push("source_code");
  }

  if (/(^|\/)(test|tests|__tests__)(\/|$)|\.(spec|test)\./.test(pathLower)) {
    score += 2;
    reasons.push("tests");
  }

  if (/\.(md|mdx|txt|rst)$/.test(pathLower)) {
    score -= 4;
    reasons.push("docs_penalty");
  }

  for (const term of terms) {
    if (snippetLower.includes(term)) {
      score += 2;
    }
    if (pathLower.includes(term)) {
      score += 1;
    }
  }

  if (reasons.length === 0) {
    reasons.push("text_match");
  }

  const confidence = Math.max(0, Math.min(0.99, score / 24));

  return {
    path: relPath,
    line: lineNumber,
    snippet,
    score,
    confidence,
    reasons,
  };
}

function buildRefKey(label: string, commit: string): string {
  const normalized = normalizeRefSegment(label);
  const suffix = commit.slice(0, 7);
  return `${normalized}__${suffix}`;
}

function normalizeRefSegment(input: string): string {
  return (
    input
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9._-]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .slice(0, 80) || "ref"
  );
}

function stripTagPrefix(tag: string): string {
  const lastSegment = tag.split("/").at(-1) ?? tag;
  return lastSegment.startsWith("v") ? lastSegment.slice(1) : lastSegment;
}

function parseSemver(input: string): Semver | null {
  const match = input
    .trim()
    .match(
      /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/,
    );
  if (!match) return null;

  const prerelease =
    match[4]
      ?.split(".")
      .map((item) => (/^\d+$/.test(item) ? Number(item) : item)) ?? [];

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
    prerelease,
  };
}

function compareSemverStrings(left: string, right: string): number {
  const a = parseSemver(left);
  const b = parseSemver(right);
  if (!a || !b) return 0;
  return compareSemver(a, b);
}

function compareSemver(left: Semver, right: Semver): number {
  if (left.major !== right.major) return left.major - right.major;
  if (left.minor !== right.minor) return left.minor - right.minor;
  if (left.patch !== right.patch) return left.patch - right.patch;

  const leftPre = left.prerelease;
  const rightPre = right.prerelease;

  if (leftPre.length === 0 && rightPre.length === 0) return 0;
  if (leftPre.length === 0) return 1;
  if (rightPre.length === 0) return -1;

  const max = Math.max(leftPre.length, rightPre.length);
  for (let i = 0; i < max; i += 1) {
    const l = leftPre[i];
    const r = rightPre[i];
    if (l === undefined) return -1;
    if (r === undefined) return 1;
    if (l === r) continue;

    if (typeof l === "number" && typeof r === "number") {
      return l - r;
    }
    if (typeof l === "number") return -1;
    if (typeof r === "number") return 1;
    return l.localeCompare(r);
  }

  return 0;
}

function satisfiesRange(version: string, rawRange: string): boolean {
  const range = rawRange.trim();
  if (!range || range === "*" || range.toLowerCase() === "latest") return true;

  const orSegments = range.split("||").map((segment) => segment.trim());
  for (const segment of orSegments) {
    if (!segment) continue;
    if (satisfiesComparatorSet(version, segment)) return true;
  }
  return false;
}

function satisfiesComparatorSet(version: string, segment: string): boolean {
  if (segment.includes(" - ")) {
    const [left, right] = segment.split(" - ").map((item) => item.trim());
    if (!left || !right) return false;
    return (
      compareVersion(version, left) >= 0 && compareVersion(version, right) <= 0
    );
  }

  const tokens = segment.split(/\s+/).filter(Boolean);
  const comparators = tokens.flatMap(expandComparator);

  for (const comparator of comparators) {
    if (!testComparator(version, comparator)) {
      return false;
    }
  }

  return comparators.length > 0;
}

function expandComparator(token: string): string[] {
  if (token === "*" || token.toLowerCase() === "latest") return [">=0.0.0"];

  if (/^[~^]/.test(token)) {
    const operator = token[0];
    const base = token.slice(1);
    const parsed = parseLooseVersion(base);
    if (!parsed) return [];

    const min = `${parsed.major}.${parsed.minor}.${parsed.patch}`;
    if (operator === "~") {
      const max = `${parsed.major}.${parsed.minor + 1}.0`;
      return [`>=${min}`, `<${max}`];
    }

    if (parsed.major > 0) {
      return [`>=${min}`, `<${parsed.major + 1}.0.0`];
    }
    if (parsed.minor > 0) {
      return [`>=${min}`, `<0.${parsed.minor + 1}.0`];
    }
    return [`>=${min}`, `<0.0.${parsed.patch + 1}`];
  }

  if (/^\d+(?:\.\d+)?(?:\.x|\.\*)$/i.test(token) || /^\d+\.x$/i.test(token)) {
    const [majorRaw, minorRaw] = token
      .toLowerCase()
      .replace("*", "x")
      .split(".");
    const major = Number(majorRaw);
    const minor =
      minorRaw === "x" || minorRaw === undefined ? null : Number(minorRaw);
    if (minor === null) {
      return [`>=${major}.0.0`, `<${major + 1}.0.0`];
    }
    return [`>=${major}.${minor}.0`, `<${major}.${minor + 1}.0`];
  }

  if (/^\d+$/.test(token)) {
    const major = Number(token);
    return [`>=${major}.0.0`, `<${major + 1}.0.0`];
  }

  if (/^\d+\.\d+$/.test(token)) {
    const [majorRaw, minorRaw] = token.split(".");
    const major = Number(majorRaw);
    const minor = Number(minorRaw);
    return [`>=${major}.${minor}.0`, `<${major}.${minor + 1}.0`];
  }

  if (/^[<>]=?|=/.test(token)) {
    return [token];
  }

  if (parseSemver(token)) {
    return [`=${token}`];
  }

  return [];
}

function parseLooseVersion(
  input: string,
): { major: number; minor: number; patch: number } | null {
  const parts = input.trim().split(".");
  if (parts.length === 0) return null;
  const major = Number(parts[0]);
  const minor = Number(parts[1] ?? "0");
  const patch = Number(parts[2] ?? "0");
  if (
    ![major, minor, patch].every((item) => Number.isInteger(item) && item >= 0)
  ) {
    return null;
  }
  return { major, minor, patch };
}

function testComparator(version: string, comparator: string): boolean {
  const match = comparator.match(/^(<=|>=|<|>|=)(.+)$/);
  if (!match) return false;
  const operator = match[1];
  const target = match[2].trim();
  const compared = compareVersion(version, target);

  switch (operator) {
    case "<":
      return compared < 0;
    case "<=":
      return compared <= 0;
    case ">":
      return compared > 0;
    case ">=":
      return compared >= 0;
    case "=":
      return compared === 0;
    default:
      return false;
  }
}

function compareVersion(left: string, right: string): number {
  const a = parseSemver(left);
  const b = parseSemver(right);
  if (!a || !b) return 0;
  return compareSemver(a, b);
}

function tokenizeQuery(query: string): string[] {
  const terms = query
    .toLowerCase()
    .split(/[^a-z0-9_.$]+/)
    .map((item) => item.trim())
    .filter((item) => item.length >= 2);
  return Array.from(new Set(terms)).slice(0, 8);
}

function isBinaryByExtension(filePath: string): boolean {
  const lower = filePath.toLowerCase();
  return [
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ico",
    ".pdf",
    ".zip",
    ".gz",
    ".tar",
    ".7z",
    ".jar",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".wasm",
    ".mp4",
    ".mp3",
    ".woff",
    ".woff2",
  ].some((extension) => lower.endsWith(extension));
}

function sanitizeVersion(input: string): string {
  return input.replace(/['"]/g, "").trim();
}

function normalizeHost(input: string): string {
  return input.trim().toLowerCase().replace(/:\d+$/, "");
}

function escapeRegex(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function errorResult(input: {
  ecosystem: string;
  packageName: string;
  packageSpec: string;
  repositoryURL?: string;
  host?: string;
  errors: LookupError[];
}): LookupResult {
  return {
    status: "error",
    source: {
      ecosystem: input.ecosystem,
      package_name: input.packageName,
      package_spec: input.packageSpec,
      repository_url: input.repositoryURL,
      host: input.host,
    },
    hits: [],
    next_actions: [],
    errors: input.errors,
  };
}

async function pathExists(filePath: string): Promise<boolean> {
  try {
    await stat(filePath);
    return true;
  } catch {
    return false;
  }
}

async function runGit(args: string[], cwd?: string): Promise<string> {
  const result = await safeExec("git", args, cwd);
  if (!result.ok) {
    throw new Error(result.stderr || result.stdout || "git command failed");
  }
  return result.stdout;
}

async function safeExec(
  command: string,
  args: string[],
  cwd?: string,
): Promise<ExecResult> {
  try {
    const result = await execFileAsync(command, args, {
      cwd,
      maxBuffer: 16 * 1024 * 1024,
    });
    return {
      ok: true,
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: 0,
    };
  } catch (error: any) {
    const exitCode = typeof error?.code === "number" ? error.code : -1;
    return {
      ok: false,
      stdout: error?.stdout ? String(error.stdout) : "",
      stderr: error?.stderr
        ? String(error.stderr)
        : error?.message
          ? String(error.message)
          : "",
      exitCode,
    };
  }
}

type ExecResult = {
  ok: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
};
