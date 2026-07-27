import { useState } from "react";
import ContextInput from "./components/ContextInput";
import ReviewEditor from "./components/ReviewEditor";
import PublishLog from "./components/PublishLog";
import { SettingsTab } from "./components/SettingsTab";

export default function App() {
  const [step, setStep] = useState("input");
  const [context, setContext] = useState("");
  const [metadata, setMetadata] = useState(null);
  const [loading, setLoading] = useState(false);

  return (
    <div className="min-h-screen p-6">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-primary">lazy-tube</h1>
        <nav className="flex gap-2">
          <button
            onClick={() => setStep("input")}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "input"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700"
            }`}
          >
            1. Create
          </button>
          <button
            onClick={() => metadata && setStep("review")}
            disabled={!metadata}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "review"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700 disabled:opacity-40"
            }`}
          >
            2. Review
          </button>
          <button
            onClick={() => setStep("log")}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "log"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700"
            }`}
          >
            3. Log
          </button>
          <button
            onClick={() => setStep("settings")}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "settings"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700"
            }`}
          >
            ⚙️ Settings
          </button>
        </nav>
      </header>

      <main>
        {step === "input" && (
          <ContextInput
            context={context}
            setContext={setContext}
            setMetadata={setMetadata}
            setLoading={setLoading}
            loading={loading}
            onComplete={() => setStep("review")}
          />
        )}

        {step === "review" && metadata && (
          <ReviewEditor
            metadata={metadata}
            setMetadata={setMetadata}
            context={context}
          />
        )}

        {step === "log" && <PublishLog />}

        {step === "settings" && <SettingsTab />}
      </main>
    </div>
  );
}