export default function ThumbnailPreview({ prompts, raw, onRegenerate, regenerating }) {
  return (
    <div className="bg-secondary p-4 rounded border border-gray-800">
      <div className="flex justify-between items-center mb-3">
        <h3 className="font-semibold text-primary">Thumbnail Prompts (Nano Banana)</h3>
        <button
          onClick={onRegenerate}
          disabled={regenerating}
          className="text-xs bg-gray-700 hover:bg-gray-600 px-2 py-1 rounded disabled:opacity-50"
        >
          {regenerating ? "..." : "Regenerate"}
        </button>
      </div>
      <p className="text-xs text-gray-400 mb-3">
        Copy these prompts into Google AI Studio (Gemini 2.5 Flash Image / Nano Banana) to generate your thumbnail.
      </p>

      {prompts && prompts.length > 0 ? (
        <div className="space-y-3 max-h-96 overflow-y-auto">
          {prompts.map((p, i) => (
            <div key={i} className="p-3 bg-surface rounded border border-gray-700">
              <div className="text-xs text-primary font-bold mb-1">
                Concept {i + 1}: {p.text_overlay || "no text"}
              </div>
              <div className="text-xs text-gray-300 mb-2">
                <strong>Prompt:</strong> {p.prompt}
              </div>
              {p.composition && (
                <div className="text-xs text-gray-400">
                  <strong>Layout:</strong> {p.composition}
                </div>
              )}
              {p.mood && (
                <div className="text-xs text-gray-400">
                  <strong>Mood:</strong> {p.mood}
                </div>
              )}
              {p.colors && (
                <div className="text-xs text-gray-400">
                  <strong>Colors:</strong> {p.colors}
                </div>
              )}
              <button
                onClick={() => navigator.clipboard.writeText(p.prompt)}
                className="mt-2 text-xs bg-primary text-secondary px-2 py-1 rounded hover:opacity-90"
              >
                Copy prompt
              </button>
            </div>
          ))}
        </div>
      ) : (
        <pre className="text-xs text-gray-300 whitespace-pre-wrap bg-surface p-3 rounded max-h-96 overflow-y-auto">
          {raw}
        </pre>
      )}
    </div>
  );
}