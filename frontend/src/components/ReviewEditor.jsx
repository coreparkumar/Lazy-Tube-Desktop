import { useState } from "react";
import { api } from "../api/client";
import ThumbnailPreview from "./ThumbnailPreview";

export default function ReviewEditor({ metadata, setMetadata, context }) {
  const [regenerating, setRegenerating] = useState(null);
  const [videoPath, setVideoPath] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState(null);

  const update = (field, value) => setMetadata({ ...metadata, [field]: value });

  const regen = async (field) => {
    setRegenerating(field);
    try {
      const result = await api.regenerate(field, context, metadata.selected_title);
      if (field === "title") {
        setMetadata({
          ...metadata,
          title_options: result.options,
          selected_title: result.options[0],
        });
      } else if (field === "thumbnail") {
        setMetadata({ ...metadata, thumbnail_prompts: result.prompts, thumbnail_raw: result.raw });
      } else {
        update(field, result[field]);
      }
    } catch (e) {
      alert("Regenerate failed: " + e.message);
    } finally {
      setRegenerating(null);
    }
  };

  const handleUpload = async () => {
    if (!videoPath.trim()) {
      alert("Please enter the path to your video file");
      return;
    }
    setUploading(true);
    setUploadResult(null);
    try {
      const finalMeta = {
        title: metadata.selected_title,
        description: metadata.description,
        tags: metadata.tags,
        category_id: metadata.category_id,
      };
      const result = await api.upload(videoPath, finalMeta);
      setUploadResult(result);
    } catch (e) {
      alert("Upload failed: " + e.message);
    } finally {
      setUploading(false);
    }
  };

  const regenBtn = (field) => (
    <button
      onClick={() => regen(field)}
      disabled={regenerating === field}
      className="text-xs bg-gray-700 hover:bg-gray-600 px-2 py-1 rounded disabled:opacity-50"
    >
      {regenerating === field ? "..." : "Regenerate"}
    </button>
  );

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 max-w-7xl mx-auto">
      <div className="space-y-4">
        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">Title</label>
            {regenBtn("title")}
          </div>
          <select
            value={metadata.selected_title}
            onChange={(e) => update("selected_title", e.target.value)}
            className="w-full p-2 bg-surface border border-gray-700 rounded text-white"
          >
            {metadata.title_options?.map((t, i) => (
              <option key={i} value={t}>{t}</option>
            ))}
          </select>
        </div>

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">Description</label>
            {regenBtn("description")}
          </div>
          <textarea
            value={metadata.description}
            onChange={(e) => update("description", e.target.value)}
            className="w-full h-48 p-2 bg-surface border border-gray-700 rounded text-white text-sm resize-none"
          />
        </div>

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">
              Tags ({metadata.tags?.length || 0})
            </label>
            {regenBtn("tags")}
          </div>
          <textarea
            value={metadata.tags?.join(", ") || ""}
            onChange={(e) =>
              update("tags", e.target.value.split(",").map((t) => t.trim()).filter(Boolean))
            }
            className="w-full h-24 p-2 bg-surface border border-gray-700 rounded text-white text-sm"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-secondary p-4 rounded border border-gray-800">
            <div className="flex justify-between items-center mb-2">
              <label className="font-semibold text-primary text-sm">Hashtags</label>
              {regenBtn("hashtags")}
            </div>
            <input
              value={metadata.hashtags?.join(" ") || ""}
              onChange={(e) => update("hashtags", e.target.value.split(" ").filter(Boolean))}
              className="w-full p-2 bg-surface border border-gray-700 rounded text-white text-sm"
            />
          </div>
          <div className="bg-secondary p-4 rounded border border-gray-800">
            <label className="font-semibold text-primary text-sm">Category</label>
            <p className="mt-2 text-sm">
              {metadata.category_name} ({metadata.category_id})
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <ThumbnailPreview
          prompts={metadata.thumbnail_prompts}
          raw={metadata.thumbnail_raw}
          onRegenerate={() => regen("thumbnail")}
          regenerating={regenerating === "thumbnail"}
        />

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <h3 className="font-semibold text-primary mb-3">Publish to YouTube</h3>
          <label className="text-sm text-gray-400">Video file path</label>
          <input
            value={videoPath}
            onChange={(e) => setVideoPath(e.target.value)}
            placeholder="D:\Videos\my-video.mp4"
            className="w-full p-2 mt-1 bg-surface border border-gray-700 rounded text-white text-sm"
          />
          <button
            onClick={handleUpload}
            disabled={uploading}
            className="mt-3 w-full bg-accent text-white font-semibold py-2.5 rounded hover:opacity-90 disabled:opacity-50 transition"
          >
            {uploading ? "Uploading..." : "Upload to YouTube"}
          </button>
          {uploadResult && (
            <div className="mt-3 p-3 bg-green-900/30 border border-green-700 rounded text-sm">
              Uploaded:{" "}
              <a href={uploadResult.url} target="_blank" rel="noreferrer" className="text-primary underline">
                {uploadResult.url}
              </a>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}