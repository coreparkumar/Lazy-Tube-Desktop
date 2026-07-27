const BASE = "/api";

async function request(path, options = {}) {
  const res = await fetch(BASE + path, {
    headers: { "Content-Type": "application/json" },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || "Request failed");
  }
  return res.json();
}

export const api = {
  generate: (context) =>
    request("/generate", { method: "POST", body: { context } }),

  regenerate: (field, context, selectedTitle) =>
    request("/regenerate", {
      method: "POST",
      body: { field, context, selected_title: selectedTitle },
    }),

  review: (metadata, status = "reviewed") =>
    request("/review", { method: "POST", body: { metadata, status } }),

  upload: (videoPath, metadata, thumbnailPath = null) => {
    const body = { video_path: videoPath, metadata };
    if (thumbnailPath) {
      body.thumbnail_path = thumbnailPath;
    }
    return request("/upload", {
      method: "POST",
      body,
    });
  },

  channel: () => request("/youtube/channel"),
  playlists: () => request("/youtube/playlists"),
  recentThumbs: (count = 5) =>
    request(`/youtube/recent-thumbnails?count=${count}`),
  auth: () => request("/youtube/authenticate", { method: "POST" }),
  publishLog: () => request("/upload/log"),
};