# GInviter

A premium, layered guild recruitment addon for World of Warcraft 3.3.5a (Wrath of the Lich King). **GInviter** brings high-efficiency recruitment workflows into a single, polished dashboard. It provides full background automation where server API permissions allow, degrading seamlessly to an assisted single-click macro workflow on servers that restrict automated `GuildInvite()` calls.

---

## Key Features

### 1. Recruiter Dashboard (`/ginviter` or Minimap Button)
- **Live Search Breakdown**: Instant summary counters for **Total Results**, **Unguilded**, **Already Invited**, **Ignored**, and **Eligible** candidates.
- **Detailed Candidate List**: Displays player level, class, and guild status with interactive hover tooltips explaining ineligibility reasons (e.g., *Already Invited Today*, *Friend*, *Ignored*, *Blacklisted*).
- **One-Click Batch Queueing**: Click `[ Recruit Everyone ]` to queue all eligible candidates automatically.

### 2. Automated Level-Slicing `/who` Scanner
- Automatically cycles through level brackets (`1-10`, `11-20`, `21-30`, ..., `71-80`) with a safe 5-second query delay to bypass WoW's 50-player search cap while staying well within server rate limits.

### 3. Layered Execution & Single-Click Fallback Mode
- **Auto Mode**: Timed background execution of whispers and invitations.
- **Assisted Fallback Mode**: If server restrictions block direct `GuildInvite()` calls, GInviter automatically toggles to a high-visibility macro action HUD:
  ```
  [ Fallback Mode - Click to Invite: PlayerName ]
  ```
  Supports rapid keybinding or mousewheel scroll binding for fast single-click invites.

### 4. Auto-Whisper & Affirmative Parsing
- Optionally sends customizable recruitment whispers before inviting.
- **Natural Language Parsing**: Automatically detects affirmative responses (`yes`, `y`, `sure`, `inv`, `invite`, `ok`, `1`) to trigger the invite, or negative responses (`no`, `n`, `pass`, `stop`) to decline and skip.
- **Timeout Fallback**: Configurable default action (Skip or Invite) if a target does not reply within the timeout window (default: 20 seconds).

### 5. Duplicate Protection & Statistics
- Configurable duplicate protection windows (`10m`, `1h`, `today`, `custom`).
- Daily recruitment statistics (Invited, Accepted, Declined, Already Guilded, Ignored, Pending).
- Searchable invite history log and blacklist manager.

### 6. Officer Network Sync & String Import/Export
- Real-time blacklist updates synchronized across online guild officers running GInviter over `CHAT_MSG_ADDON`.
- Base64 string encoder/decoder for sharing recruiter profiles, filter presets, and blacklists via chat or discord.

---

## Installation

1. Download or clone this repository.
2. Place the `GInviter` folder into your World of Warcraft AddOns directory:
   ```text
   World of Warcraft 3.3.5a/Interface/AddOns/GInviter/
   ```
3. Restart WoW or reload your UI (`/console reloadui`).

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ginviter` or `/ginvite` | Toggle the Recruiter Dashboard UI. |
| `/ginviter start` | Start or resume queue processing. |
| `/ginviter stop` or `/ginviter pause` | Pause queue processing. |
| `/ginviter clear` | Clear the current recruitment queue. |
| `/ginviter stats` | Print today's recruitment statistics in chat. |
| `/ginvite <PlayerName>` | Directly queue and invite a specific player. |

---

## Repository & License

- **Author**: Zendevve
- **Version**: 1.0.0
- **Target Game Version**: World of Warcraft 3.3.5a (Wrath of the Lich King - Interface `30300`)
- **License**: Proprietary / Personal Use Terms (See [`LICENSE.md`](LICENSE.md))
