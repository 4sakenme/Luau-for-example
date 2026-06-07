# Server-Authoritative Luau Anti-Cheat System

A robust, modular, and server-authoritative anti-cheat solution designed for Roblox using Luau. This system is built to minimize client-side reliance, handling all critical detection vectors on the server to prevent exploits from bypassing security layers.

## 🛠️ Architecture & Modules

The system is split into specialized modules, coordinated by a central risk scoring framework to eliminate false positives caused by network latency or lag.

*   **`SpeedCheck.luau`**: Monitors player velocity and distance traveled over delta time. Cross-references movement with expected physics states to catch speed exploits.
*   **`TeleportCheck.luau`**: Detects sudden, unauthorized coordinate changes (instantaneous movement) across the map.
*   **`FlyCheck.luau`**: Tracks the player's vertical movement, raycasting downwards to verify if they are supported by a floor or genuinely airborne.
*   **`NoclipCheck.luau`**: Validates character geometry against structural parts using spatial queries to prevent players from walking through walls.
*   **`RemoteSpamCheck.luau`**: A network rate-limiter that throttles and logs excessive incoming remote event traffic to mitigate crash-server exploits and remote abuse.
*   **`RiskScoreSystem.luau`**: The core intelligence unit. Instead of instantly banning players for single-frame lag spikes, it accumulates a "Risk Score" based on suspicious flags. 
*   **`FlagLogger.luau`**: Handles secure internal logging of flagged behaviors for developer review.
*   **`PunishmentHandler.luau`**: Executes server-side actions (e.g., rubberbanding, kicking, or logging data) once a player's Risk Score exceeds defined thresholds.

## ✨ Key Technical Highlights

*   **Server-Authoritative Design**: Zero reliance on the client to report its own state. 
*   **Adaptive Anti-Lag**: The risk scoring system ensures high-ping players or those experiencing frame drops don't trigger false bans.
*   **Optimized Performance**: Built natively in Luau, leveraging task scheduling efficiently without causing server tick rate drops.
