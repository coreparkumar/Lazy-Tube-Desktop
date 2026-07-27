# lazy-tube

> AI-powered YouTube publishing assistant. Local-first. Brand-consistent. Dead simple.

lazy-tube takes a **text description** of your video and turns it into fully optimized YouTube metadata - **titles, descriptions, tags, hashtags, category, and Google Nano Banana thumbnail prompts** - using local LLMs via Ollama. Then it uploads straight to YouTube with one click.

No cloud LLM. No monthly fees. No vendor lock-in. Just your machine and your channel.

---

## Table of Contents
- [Why lazy-tube?](#why-lazy-tube)
- [Features](#features)
- [How It Works](#how-it-works)
- [Tech Stack](#tech-stack)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Project Structure](#project-structure)
- [Brand Profile Guide](#brand-profile-guide)
- [Managing Multiple Topics (Channel Bracket System)](#managing-multiple-topics-channel-bracket-system)
- [Thumbnail Workflow](#thumbnail-workflow)
- [YouTube Feature Reference](#youtube-feature-reference)
- [Daily Workflow](#daily-workflow)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## Why lazy-tube?

If you publish YouTube videos regularly, you have probably noticed:

1. **Writing metadata is tedious** - title variations, description structure, tag research, hashtags...
2. **Maintaining visual consistency is hard** - every thumbnail ends up looking slightly different
3. **Cloud AI tools charge per request** - and you give them your creative data
4. **YouTube Studio is slow** - multi-step uploads with no automation

lazy-tube solves all of this:

| Problem | lazy-tube Solution |
|---------|-------------------|
| Writing titles | 5 optimized options in 5 seconds |
| Description structure | Template-driven, brand-matched |
| Tag research | AI-generated, 20+ ranked tags |
| Hashtags | Channel tag + 3 video-specific |
| Thumbnail concept | 3 Nano Banana-ready prompts |
| Visual consistency | Brand profile + channel brackets |
| API costs | Free (local Ollama) |
| Data privacy | Everything runs locally |

---

## Features

### Core
- **Title Generation** - 5 variations, multiple styles (curiosity, how-to, listicle, news)
- **Description Generation** - Template-driven, brand-consistent
- **Tag Generation** - 20-25 ranked tags (broad + long-tail)
- **Hashtag Generation** - Channel tag + 3 video-specific
- **Category Classification** - Auto-maps to YouTube's 15 categories
- **Thumbnail Prompts** - 3 Nano Banana (Gemini 2.5 Flash Image) prompts per video

### Workflow
- **Human-in-the-loop review** - Edit any field, regenerate any field
- **Brand profile** - Single YAML file controls all outputs
- **Channel bracket system** - Manage multiple series in one channel
- **Reference thumbnails** - Pulls your recent uploads for style matching
- **Desktop OAuth** - Secure local token, no server-side auth
- **Publish log** - Track all uploads with timestamps and URLs

### Architecture
- **Local LLM** - llama3.1 (default), mistral (high quality), phi3 (fast drafts)
- **Async FastAPI backend** - Parallel skill execution
- **Electron + React UI** - Desktop app, no browser needed
- **Resumable uploads** - Handles 256GB files reliably
- **Restart-safe** - Tokens and logs persist across restarts

---

## How It Works

+-------------------------------------------------------------+ | 1. INPUT: You describe your video in plain text | | "10-min Rust tutorial for JS devs, covers ownership..." | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 2. AI PROCESSING (local Ollama, 6 parallel skills) | | |-- Title (5 options) | | |-- Description (template-driven) | | |-- Tags (20-25 ranked) | | |-- Hashtags (channel + video-specific) | | |-- Category (auto-classified) | | +-- Thumbnail (3 Nano Banana prompts) | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 3. REVIEW: You edit, regenerate, or accept | | . Side-by-side editor | | . Per-field regeneration | | . Thumbnail prompt preview | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 4. THUMBNAIL: You generate in Google AI Studio | | . Copy prompt -> Nano Banana -> Save image | | . (Optional) Add text overlay in Canva | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 5. PUBLISH: One-click upload to YouTube | | . Resumable upload | | . Auto-set thumbnail | | . Logged to publish_log.json | +-------------------------------------------------------------+


---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Backend | FastAPI (Python 3.10+) | Async, fast, clean |
| LLM | Ollama (local) | Free, private, fast |
| Models | llama3.1, mistral, phi3 | Local, no API costs |
| Image prompts | Google Nano Banana (Gemini 2.5 Flash) | Best 16:9 thumbnails |
| YouTube API | google-api-python-client | Official, resumable |
| Frontend | Electron + React + Vite | Desktop feel, local-first |
| Styling | Tailwind CSS | Fast iteration |
| Storage | Local JSON + YAML | No database needed |

---

## Quick Start

### Prerequisites
- **Python 3.10+**
- **Node.js 18+**
- **Ollama** (install from https://ollama.com)
- **YouTube channel** + Google account

### One-time setup

```powershell
# 1. Pull Ollama models
ollama pull llama3.1
ollama pull mistral

# 2. Run the bootstrapper
cd D:\GitHub\lazy-tube
powershell -ExecutionPolicy Bypass -File setup.ps1

# 3. Install Python dependencies
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r ..\requirements.txt
cd ..

# 4. Install Node dependencies
cd frontend
npm install
cd ..

# 5. Set up YouTube API (see api-guide.md)
#    Save OAuth JSON as: data\client_secrets.json

# 6. Edit your brand profile
notepad data\brand_profile.yaml
Run
.\start.ps1
This opens:

Backend terminal: http://localhost:8000
Electron window: auto-opens when ready
First upload
Type your video context
Click "Generate Metadata"
Review/edit fields
Copy a thumbnail prompt -> generate in Google AI Studio -> save image
Enter video path + thumbnail path
Click "Upload to YouTube"
First time: browser opens for Google OAuth
Done - video is uploaded as private. Change to public in YouTube Studio when ready.
Detailed Setup
1. Ollama Setup
# Install from https://ollama.com
ollama pull llama3.1        # 4.7GB - default
ollama pull mistral         # 4.1GB - high quality
ollama pull phi3:mini       # 2.3GB - fast drafts (optional)
ollama list                 # verify
ollama serve                # if not auto-started
RAM requirements:

llama3.1 (8B): 8GB+ recommended
mistral (7B): 8GB+ recommended
Both together: 16GB+ recommended
2. YouTube API Setup
See api-guide.md for the complete walkthrough. Summary:

Create GCP project
Enable YouTube Data API v3
Configure OAuth consent screen
Create OAuth 2.0 Desktop app credentials (NOT Web app)
Download JSON -> save as data/client_secrets.json
Critical: Use "Desktop app" type. lazy-tube uses a local OAuth flow.

3. Brand Profile
Edit data/brand_profile.yaml. This is the most important file - it controls all outputs.

4. Channel Brackets (Optional but Recommended)
If your channel has multiple series, configure the bracket system.

Project Structure
lazy-tube/
+- backend/                        # FastAPI + Ollama skills
|  +- main.py                    # App entry point
|  +- api/
|  |  +- generate.py            # POST /generate
|  +- skills/                    # One file per metadata field
|  +- core/                      # Infrastructure
+- frontend/                       # Electron + React + Vite
|  +- main.js                    # Electron main process
|  +- src/
|     +- App.jsx
|     +- components/
+- config/                         # Runtime config
+- data/                           # User data (gitignored)
|  +- brand_profile.yaml         # <-- EDIT THIS
|  +- client_secrets.json        # <-- YouTube OAuth
+- logs/                           # Auto-generated logs
+- api-guide.md                    # YouTube API setup
+- README.md                       # This file
+- setup.ps1                       # Project bootstrapper
+- start.ps1                       # Launch script
+- requirements.txt
Brand Profile Guide
The brand profile (data/brand_profile.yaml) is your single source of truth for channel identity.

Channel identity
channel:
  name: "TechSimplified"
  tone: "informative, friendly, slightly humorous"
  audience: "developers, tech enthusiasts"
  about: "We make complex tech topics simple."
Visual brand
visual_brand:
  primary_color: "#00D4FF"
  secondary_color: "#1A1A2E"
  accent_color: "#FF006E"
  mood: "modern, clean, futuristic"
Title style
title_style:
  pattern: "{topic}: {hook}"
  examples:
    - "Rust is Eating JavaScript: Heres Why"
    - "5 Python Tricks I Wish I Knew Earlier"
Description template
description_template: |
  {hook}

  In this video:
  {bullets}

  Timestamps:
  0:00 Intro
  {chapters}

  Links:
  {links}
  {hashtags}
Hashtags
hashtags_fixed:
  - "YourChannelTag"      # Always included
Pro tips
More examples = better AI output. Add 5-10 real title examples.
Be specific about tone. "sarcastic and edgy" is different from "playful and educational".
Update visual colors when you rebrand. The AI adapts thumbnails.
Keep the description template simple. The AI fills the variables.
Managing Multiple Topics (Channel Bracket System)
The problem
You want ONE channel but MULTIPLE series. Each series may need different:

Playlists
Visual mood
Sometimes even colors
The solution: Channel brackets
Configure in brand_profile.yaml:

channel_bracket_system:
  - topic: "AI & Machine Learning"
    playlist_name: "AI Weekly"
    visual_mood: "futuristic, neon, dark backgrounds"
  - topic: "Python Development"
    playlist_name: "Python Tips"
    visual_mood: "clean, code-on-screen, light backgrounds"
  - topic: "Tool Reviews"
    playlist_name: "Tool Showdown"
    visual_mood: "product shots, side-by-side comparisons"
When you generate metadata, the AI:

Reads your context
Matches it to the most relevant bracket
Applies that bracket's visual mood to thumbnail prompts
Tags the description with the right playlist name
The 3 pillars of uniformity
1. Visual (thumbnails)

Same color palette (or accept the bracket override)
Same font, same logo position
Same composition (e.g., "subject right, text left")
2. Verbal (titles & descriptions)

Same fixed hashtag in every video
Same intro sentence in every description
Same title structure pattern
3. Structural (video itself)

Same intro length (5-10 sec)
Same outro
Same chapter style
These go in your brand_profile.yaml and apply across all brackets.

Thumbnail Workflow
Step 1: AI generates prompts
In the review screen, you will see 3 Nano Banana prompts like:

Concept 1: GPT-5 IS HERE
Prompt: Cinematic shot of a glowing neural network...
TextOverlay: GPT-5 IS HERE
Mood: futuristic, exciting
Colors: #00D4FF, #1A1A2E, #FF006E
Step 2: Generate in Google AI Studio
Go to https://aistudio.google.com
Select "Gemini 2.5 Flash Image" (Nano Banana)
Paste the prompt
Click "Generate"
Download the image
Step 3: Add text overlay (optional)
Canva (free): Use your brand fonts
Photoshop: Pro control
Figma: Quick and clean
Match the TextOverlay and Colors from the AI prompt.

Step 4: Upload
In lazy-tube, paste the image path. The app auto-uploads it to YouTube with your video.

Tips
Always test multiple concepts. YouTube has a free A/B test tool.
Match the thumbnail to the title. Do not oversell.
Use high contrast. Mobile thumbnails are tiny.
Avoid more than 5 words on the thumbnail.
YouTube Feature Reference
When to use each feature
Feature	When to Use	Why It Matters
Playlists	Group videos by topic/series	SEO + viewer binge-watch
Tags	Always fill all 30 slots	Search discoverability
Chapters	Videos > 2 min	SEO + viewer experience
End screens	Last 20 sec of video	Promote next video
Cards	Mid-video topic mentions	Cross-link old content
Pinned comment	Every upload	Engagement boost
Community tab	1-2x/week	Channel activity signal
Shorts	Repurpose long video highlights	10x reach
Premieres	Major launches only	Hype + live chat replay
Thumbnails A/B	Always test	YouTube's free tool
Analytics checklist (weekly)
Audience tab - what topics do viewers actually want?
Traffic sources - where are views coming from?
Top videos - what is working? Make more like it.
CTR + AVD - if CTR < 4%, test new thumbnails.
Comments - answer every comment in first hour.
Daily Workflow
Publishing a new video
Edit & export your video (e.g., D:\Videos\my-video.mp4)
Open lazy-tube (.\start.ps1)
Type context: "10-min Rust tutorial for JS devs..."
Generate metadata (5-10 sec)
Review titles, edit description, check tags
Copy thumbnail prompt -> Google AI Studio -> save image
(Optional) Add text overlay in Canva
Enter paths in upload section
Click Upload - browser opens for OAuth (first time only)
Set visibility in YouTube Studio (private -> public)
Post community tab announcement
Check publish_log.json to confirm
Troubleshooting
Ollama issues
"Connection refused" to localhost:11434

ollama serve
"Model not found"

ollama pull llama3.1
ollama list
Slow generation

Use phi3:mini for drafts (2.3GB)
Reduce temperature in prompts
Close other heavy apps
YouTube API issues
"redirect_uri_mismatch"

Make sure you selected Desktop app type, NOT Web app
Desktop flow does not need manual redirect URI
"access_denied"

Add your email as a test user in OAuth consent screen
Make sure you granted all 3 scopes
"quotaExceeded"

YouTube default: 10,000 units/day
1 upload = 1,600 units -> max 6 uploads/day
Request increase: Cloud Console -> APIs & Services -> YouTube Data API v3 -> Quotas
"Video not found" after upload

Check logs/publish_log.json for the video ID
Visit https://youtu.be/{video_id} directly
Frontend issues
Electron window does not open

Check the backend terminal for errors
Open http://localhost:5173 in browser manually to debug
CORS errors

Backend runs on port 8000, frontend on 5173
Check frontend/vite.config.js proxy settings
Tailwind styles not applying

cd frontend
npm install
npm run dev
General
AI output is low quality

Add more examples to brand_profile.yaml
Be more specific in your context
Try a different model (mistral for quality, phi3 for speed)
Thumbnail prompt is generic

Add 5-10 reference thumbnails from your channel
Be more specific in your video context
Add custom style notes to brand_profile.yaml
Roadmap
v0.2 (next)
 Whisper transcription for video input mode
 Auto-fetch chapter timestamps from video
 Bulk video processing
 Schedule publish (date/time)
 Multi-channel support
v0.3
 YouTube Analytics integration
 A/B test thumbnail picker
 Auto-publish to TikTok/Instagram Reels
 Local Stable Diffusion for thumbnails (no Nano Banana)
 Video SEO scoring (out of 100)
v1.0
 Cloud sync (optional, encrypted)
 Team collaboration
 Plugin system
 Web version (in addition to desktop)
Contributing
This is a personal tool, but if you fork it and improve it, I would love to hear about it. Open an issue with:

What you changed
Why it is better
Screenshots if UI-related
License
MIT - do whatever you want. Just do not blame me if your YouTube channel goes viral. ;)

Credits
Built with:

Ollama - local LLMs
FastAPI - backend
React + Electron - frontend
Tailwind CSS - styling
Google Nano Banana - thumbnail generation
YouTube Data API v3 - publishing
Happy publishing!