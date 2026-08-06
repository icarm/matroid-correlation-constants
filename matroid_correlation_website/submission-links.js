import { siteConfig } from "./catalog.js";

const inferGitHubRepository = () => {
  if (siteConfig.githubRepositoryUrl) {
    return siteConfig.githubRepositoryUrl.replace(/\/$/, "");
  }
  if (!window.location.hostname.endsWith(".github.io")) return null;
  const owner = window.location.hostname.slice(0, -".github.io".length);
  const [repository] = window.location.pathname.split("/").filter(Boolean);
  return owner && repository
    ? "https://github.com/" + owner + "/" + repository
    : null;
};

const repository = inferGitHubRepository();
if (repository) {
  document.querySelectorAll(".github-submission-link").forEach((link) => {
    link.href =
      repository +
      "/issues/new?template=" +
      encodeURIComponent(link.dataset.issueTemplate);
  });
}
