import React, { useState, useEffect } from "react";

export function SettingsTab() {
  const [yamlContent, setYamlContent] = useState("");
  const [statusMsg, setStatusMsg] = useState("");
  const [channelStatus, setChannelStatus] = useState({
    secrets_uploaded: false,
    channel_connected: false,
  });

  const fetchChannelStatus = async () => {
    try {
      const res = await fetch("/api/settings/channel-status");
      const data = await res.json();
      setChannelStatus(data);
    } catch (e) {
      console.error("Failed to load channel status:", e);
    }
  };

  useEffect(() => {
    fetch("/api/settings/brand-profile")
      .then((res) => res.json())
      .then((data) => setYamlContent(data.yaml_content || ""));
    fetchChannelStatus();
  }, []);

  const handleSaveYaml = async () => {
    setStatusMsg("Saving brand profile...");
    try {
      const res = await fetch("/api/settings/brand-profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ yaml_content: yamlContent }),
      });
      const data = await res.json();
      setStatusMsg(data.message || data.detail);
    } catch (err) {
      setStatusMsg("Failed to save brand profile.");
    }
  };

  const handleFileUpload = async (e) => {
    if (!e.target.files[0]) return;
    const formData = new FormData();
    formData.append("file", e.target.files[0]);
    setStatusMsg("Uploading client secrets...");
    try {
      const res = await fetch("/api/settings/upload-client-secrets", {
        method: "POST",
        body: formData,
      });
      const data = await res.json();
      setStatusMsg(data.message);
      fetchChannelStatus();
    } catch (err) {
      setStatusMsg("Failed to upload client secrets.");
    }
  };

  const handleConnectChannel = async () => {
    setStatusMsg("Opening Google OAuth in your default browser...");
    try {
      const res = await fetch("/api/settings/connect-youtube", {
        method: "POST",
      });
      const data = await res.json();
      setStatusMsg(data.message || data.detail);
      fetchChannelStatus();
    } catch (err) {
      setStatusMsg("Authorization failed or was cancelled.");
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-5">
        <h2 className="text-lg font-semibold text-gray-200 mb-2">
          1. YouTube Channel Authorization
        </h2>
        <p className="text-sm text-gray-400 mb-4">
          Connect your account using a Google OAuth Client Secret JSON file.
        </p>

        <div className="flex gap-4 items-center mb-4 text-sm">
          <span className="text-gray-300">
            Credentials:{" "}
            <span
              className={
                channelStatus.secrets_uploaded
                  ? "text-green-400 font-medium"
                  : "text-red-400 font-medium"
              }
            >
              {channelStatus.secrets_uploaded ? "Uploaded" : "Missing"}
            </span>
          </span>
          <span className="text-gray-300">
            Channel:{" "}
            <span
              className={
                channelStatus.channel_connected
                  ? "text-green-400 font-medium"
                  : "text-yellow-400 font-medium"
              }
            >
              {channelStatus.channel_connected
                ? "Connected"
                : "Not Authenticated"}
            </span>
          </span>
        </div>

        <div className="space-y-3">
          <label className="block text-xs font-medium text-gray-400">
            Upload client_secrets.json:
          </label>
          <input
            type="file"
            accept=".json"
            onChange={handleFileUpload}
            className="text-xs text-gray-300 file:mr-4 file:py-1.5 file:px-3 file:rounded file:border-0 file:text-xs file:font-semibold file:bg-gray-800 file:text-gray-200 hover:file:bg-gray-700 cursor-pointer"
          />

          <div className="pt-2">
            <button
              onClick={handleConnectChannel}
              disabled={!channelStatus.secrets_uploaded}
              className="px-4 py-1.5 rounded text-sm font-medium bg-primary text-secondary hover:bg-cyan-400 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Authorize / Switch Channel
            </button>
          </div>
        </div>
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-lg p-5">
        <h2 className="text-lg font-semibold text-gray-200 mb-2">
          2. Edit Brand Profile Rules (`brand_profile.yaml`)
        </h2>
        <p className="text-sm text-gray-400 mb-3">
          Customize AI prompting styles, hashtags, visual brackets, and upload
          defaults.
        </p>

        <textarea
          rows={16}
          className="w-full bg-gray-950 border border-gray-800 rounded p-3 text-xs font-mono text-cyan-300 focus:outline-none focus:border-primary"
          value={yamlContent}
          onChange={(e) => setYamlContent(e.target.value)}
        />

        <button
          onClick={handleSaveYaml}
          className="mt-3 px-4 py-1.5 rounded text-sm font-medium bg-primary text-secondary hover:bg-cyan-400 transition"
        >
          Save Brand Profile
        </button>
      </div>

      {statusMsg && (
        <div className="p-3 bg-gray-900 border-l-4 border-primary rounded text-sm text-gray-200">
          <strong>Status:</strong> {statusMsg}
        </div>
      )}
    </div>
  );
} 