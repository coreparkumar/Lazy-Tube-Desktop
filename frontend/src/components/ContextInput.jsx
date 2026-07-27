import { useState } from "react";
import { api } from "../api/client";

export default function ContextInput({
  context, setContext, setMetadata, setLoading, loading, onComplete
}) {
  const [error, setError] = useState("");

  const handleGenerate = async () => {
    if (!context.trim()) {
      setError("Please enter video context");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const result = await api.generate(context);
      setMetadata(result);
      onComplete();
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto">
      <div className="bg-secondary rounded-lg p-6 border border-gray-800">
        <h2 className="text-xl font-semibold mb-2">Describe Your Video</h2>
        <p className="text-gray-400 text-sm mb-4">
          Topic, key points, target audience. The more detail, the better the metadata.
        </p>
        <textarea
          value={context}
          onChange={(e) => setContext(e.target.value)}
          placeholder="Example: A 10-minute tutorial on getting started with Rust for JavaScript developers. Cover ownership, borrowing, and build a small CLI tool. Target audience: intermediate JS devs who want to learn Rust."
          className="w-full h-48 p-3 bg-surface border border-gray-700 rounded text-white resize-none focus:border-primary focus:outline-none"
        />
        {error && <p className="text-accent mt-2 text-sm">{error}</p>}
        <button
          onClick={handleGenerate}
          disabled={loading}
          className="mt-4 w-full bg-primary text-secondary font-semibold py-3 rounded hover:opacity-90 disabled:opacity-50 transition"
        >
          {loading ? "Generating with Ollama..." : "Generate Metadata"}
        </button>
      </div>
    </div>
  );
}