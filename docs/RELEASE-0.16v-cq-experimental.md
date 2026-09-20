# FPSloppa 0.16v CQ Experimental — Vesper campaign

Standalone **CQ / UT99** clients and distributed servers for the **81-district Vesper city**, with **128 players overall and 16 per district**. This protocol is separate from main FPSloppa.

- **Moderator menu:** F8 unlocks master-verified, password-protected controls. Teleport to districts or players, bring players to you, and hold F9 for a bounded global voice announcement. Passwords are configured on the master; no default is shipped. Teleports preserve district capacity and use safe landing checks.
- **Persistent arrivals:** new players start in the no-fire inner city. Returning players resume at their saved location when available; full/unavailable districts fall back to the nearest friendly sector, then eligible neutral territory or the waiting room. Workers checkpoint location every five seconds and on orderly logout.
- **Campaign city:** 81 individually compiled and baked BSP29 districts, homebase perimeters, capturable relays, inner-city terminals and scoreboard, UTC-midnight victory points and persistent campaign progress.
- **CQ soundtrack:** quiet district ambience, combat orchestral music and a quiet military-themed menu score. Global announcements duck the soundtrack.
- **Quick deployment:** packaged shell scripts prepare and install master, worker/gateway and VPN-ingress components from simple cfg files. Includes compact five-VPS and spread nine-VPS inventory examples, persistent player storage and a static campaign status page.

Downloads:

- **Linux / Windows:** standalone Vulkan desktop client, all 81 baked presentation maps and audio. Activate the administrator's WireGuard profile, then open the supplied client JSON or save it beside the executable as `client.json`.
- **Server-Linux:** console-only runtime, all 81 worker maps, Python services, cfg examples and deployment scripts. Start with `README.md`. Set moderation with `set-moderator-password.sh`; prepare deployment with `prepare-deployment.sh`, then install with `deploy-components.sh`.
- **Source:** experimental branch sources and campaign assets.

Validation covers master authorization, capacity and persistence rules; real cross-region worker teleports and voice fanout; Linux/Vulkan moderator UI; saved-position restoration; packaged client/server, ENet and custom-VRM checks. Windows is built and inspected but has not been executed on a native Windows host. Voice media checks use synthetic PCM; live microphone/hardware and WAN/128-player combat remain live-test work. No Quest or Pico CQ artifact is included. Stable/main remains on its separate release channel.
