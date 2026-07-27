import { useState, useEffect } from "react";
import { api } from "../api/client";

export default function PublishLog() {
  const [log, setLog] = useState([]);

  useEffect(() => {
    api.publishLog()
      .then((d) => setLog(d.log || []))
      .catch(console.error);
  }, []);

  return (
    <div className="max-w-4xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Publish Log</h2>
      {log.length === 0 ? (
        <p className="text-gray-400">No uploads yet. Publish your first video!</p>
      ) : (
        <div className="space-y-2">
          {log.slice().reverse().map((entry, i) => (
            <div key={i} className="bg-secondary p-3 rounded border border-gray-800">
              <div className="flex justify-between items-start">
                <span className="font-semibold">{entry.title}</span>
                <span className="text-xs text-gray-400">
                  {new Date(entry.timestamp).toLocaleString()}
                </span>
              </div>
              <a
                href={entry.url}
                target="_blank"
                rel="noreferrer"
                className="text-primary text-sm underline"
              >
                {entry.url}
              </a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}