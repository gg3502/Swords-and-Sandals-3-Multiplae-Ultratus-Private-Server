# Swords & Sandals 3: Multiplae Ultratus — Private Server Guide

This repository lets you host your own multiplayer server for **Swords & Sandals 3: Multiplae Ultratus**, since the original official servers (hosted via Fizzy/gotoAndPlay's SmartFoxServer backend) have been offline for years.

This guide covers standing up a **SmartFoxServer PRO 1.x** instance, installing the included server extension (`ssmp_db.as`), and patching your own copy of the game client to work with a private server.

> **This repo does not include the game, its assets, or the game's SWF file.** Swords & Sandals 3 is copyrighted software owned by 3rd Sense Australia Pty Ltd. You must extract the multiplayer client from your own legally-owned copy of the game and apply the patches below yourself. This repository only contains **original work**: the server-side extension (`ssmp_db.as`) and this setup/patch guide.

---

## What you need

1. **`swords_sandals_3_multiplae_ultratus.swf`** — the standalone multiplayer client file. This repo does not provide it; finding a copy is up to you (search engines are your friend — copies have circulated as a standalone SWF, separate from the solo game executable).
2. **Game assets** (`arenas`, `weapons`, `anims`, `armguards`, `helmets`, etc.) — the multiplayer SWF loads these at runtime via relative paths and won't render properly without them. You can pull these from the Steam "Classic Collection" install, or from a standalone Swords and Sandals 3: Multiplae Ultratus demo executable — copies of which are also still findable online. Either source's asset folders should work, since they share the same folder structure.
3. **[JPEXS Free Flash Decompiler (FFDec)](https://github.com/jindrapetrik/jpexs-decompiler)** — used to open, edit, and recompile the SWF. No resource-extraction tools needed — this is already a plain standalone `.swf` file.
4. **`ssmp_db.as`** (included in this repo) — the server-side extension providing gladiator save/load, Hall of Fame, and battle logic.
5. **SmartFoxServer PRO 1.x** and a **Java 6** runtime — see below.
6. **A standalone Flash Player Projector** — to run the patched `.swf`, since browsers no longer support Flash.

---

## Step 1: Get the multiplayer client and its assets

- Locate a copy of `swords_sandals_3_multiplae_ultratus.swf` — where you get this is up to you.
- Separately, gather the asset folders it needs at runtime. The easiest sources are the Steam Classic Collection install or an old Multiplae Ultratus demo executable's install folder — grab the `assets`-related subfolders (`arenas`, `weapons`, `anims`, `armguards`, `helmets`, `boots`, etc.) and place them in the same folder as the SWF, preserving their original relative structure.
- Open the SWF directly in FFDec to apply the patches below — since it's already a standalone file, there's no extraction step required.

---

## Step 2: Apply client-side patches

The original client has several issues that block private-server hosting or cause crashes once real gameplay data (saved gladiators, equipped items) flows through it. Apply each of the following in FFDec's ActionScript editor, then use **Save** (not Export) to recompile the change into the SWF.

### 2.1 — Point the client at your server

In the `"connect"` frame script, find:

```actionscript
var ip = "174.129.238.160";
var port = 9339;
var zone = "swords_sandals_multiplayer";
```

Change `ip` to your server's address (`127.0.0.1` for local testing, your LAN IP, your public IP with port forwarding, or a mesh VPN address like Tailscale for internet play).

### 2.2 — Persistent player ID

Since this client relies on a per-connection session ID (`smartfox.myUserId`) that changes on every reconnect, gladiator saves would otherwise "disappear" any time the client reconnects. Add a stable, locally-stored ID instead.

In the same `"connect"` frame script, right after the username/guest-name setup block (before `sendServer("get_game_count_free")`), add:

```actionscript
var glad_local_id = SharedObject.getLocal("ss3_player_id");
if(glad_local_id.data.player_id == undefined)
{
   glad_local_id.data.player_id = "player_" + Math.floor(Math.random() * 100000000) + "_" + getTimer();
   glad_local_id.flush();
}
_root.user_id = glad_local_id.data.player_id;
_global.user_id = _root.user_id;
```

### 2.3 — Bypass demo/membership gating

The original client gated content (level cap, gladiator limits, "Become a Fizzy VIP" nag screens) behind a now-defunct third-party membership API (`FizzyAPIas2`), which always evaluates to "demo/guest" since the service no longer exists.

Find the `FizzyAPIas2` class definition and replace the body of its static `isDemo()` method:

```actionscript
static function isDemo()
{
   return false;
}
```

Find `check_fizMember()` (in the script alongside `call_fizMbCheck()`/`sendServer`) and replace its body:

```actionscript
function check_fizMember()
{
   _root.fizMb = 2;
   return _root.fizMb;
}
```

### 2.4 — Fix the switch-statement compile limit (`item_powers`)

FFDec cannot save the original `item_powers()` function as-is — its ~240-case `switch` statement exceeds FFDec's internal jump-table size limit (`Generated offset for Switch is larger than maximum allowed for SI16`). Restructure the single switch into three, split by case-number range and gated by `if`/`else if`:

```actionscript
if (powernum <= 80)
{
   switch(powernum)
   {
      // cases 0–80, unchanged
   }
}
else if (powernum <= 160)
{
   switch(powernum)
   {
      // cases 81–160, unchanged
   }
}
else
{
   switch(powernum)
   {
      // cases 161–241, unchanged
   }
}
```

No case logic changes — just repackaging into three smaller switches so each stays under FFDec's limit.

### 2.5 — Fix crash on loaded gladiators with empty weapon slots (`add_DNA`)

`dungeons_and_dragons()` (called whenever the character sheet or a battle loads) unconditionally reads `inv_item9`/`inv_item10` (offhand/weapon slots), but `add_DNA()` only creates those objects when real item data exists — leaving them `undefined` for any gladiator with empty hands, which crashes the stats screen.

In `add_DNA()`'s final inventory-reconstruction loop, add an `else` branch for the weapon slots specifically:

```actionscript
i = 1;
while(i <= which_gladiator.inventory.max_items + 1)
{
   which_gladiator.inventory["inv" + i] = DNA_object != null ? String(inventory_array[i]) : String(0);
   if(which_gladiator.inventory["inv" + i] != "0" && which_gladiator.inventory["inv" + i] != "undefined")
   {
      inv_item = which_gladiator["inv_item" + i] = new Object();
      inv_item.item_DNA = which_gladiator.inventory["inv" + i];
      if(inv_item.item_DNA != undefined)
      {
         make_new_item(inv_item,inv_item,false,null);
      }
   }
   else if(i == 9 || i == 10)
   {
      inv_item = which_gladiator["inv_item" + i] = new Object();
      inv_item.item_type = 0;
      inv_item.melee_type = 1;
      inv_item.base_armour = 0;
      inv_item.item_name = "";
   }
   i++;
}
```

### 2.6 — Fix synchronous infinite-loop freeze on item load (`do_load_item`)

Once real equipped items load during a battle for the first time, a `while` loop in `do_load_item()` can spin forever synchronously (freezing the client with a "script running slowly" prompt) if `colored` never flips true in a single pass. Change the `while` to a plain `if`, and fix the cleanup condition to check the correct object:

```actionscript
if(TotalBytes > 0 && LoadedBytes >= TotalBytes)
{
   this.force_load_counter = 0;
   if(this.targetMC.colored != true)
   {
      _root.colourise_item(this.targetMC,this,this.use_spawn,this.primary);
      this.targetMC._parent.hair._visible = false;
      this.targetMC._parent.ears._visible = false;
      this.onEnterFrame = null;
      this.killMovieClip();
   }
}
```

### 2.7 — Fix Load Gladiator list appearing blank intermittently

`init_database_room()` only made the gladiator list grid visible under one specific membership tier, and its own request to fetch the list can arrive before the screen finishes attaching. Update it to always show the grid regardless of tier, and add a short delay before requesting data:

```actionscript
else
{
   database_room.gladiatorList_dg._visible = database_room.g_list_box._visible = database_room.delete_button._visible = database_room.reaper._visible = true;
   database_room.gladiator_list_text.text = "";
   database_room.status_text.text = "";
   setTimeout(show_gladiators_from_database, 300);
}
```

### 2.8 — Send real inventory data on save (also in the same script as 2.7)

The original save functions only sent character stats, never equipped items, so nothing persisted across sessions. Add a helper and call it before saving:

```actionscript
function build_inv_string(which_gladiator)
{
   var inv_string = "0";
   var ii = 1;
   while(ii <= which_gladiator.inventory.max_items + 1)
   {
      inv_string += "^" + String(which_gladiator.inventory["inv" + ii]);
      ii++;
   }
   return inv_string;
}
```

Then in both `add_gladiator_to_database()` and `save_current_gladiator()`, add `my_gladiator.vitals.inv = build_inv_string(my_gladiator);` right before the `smartfox.sendXtMessage(extensionName, "addData"/"saveData", my_gladiator.vitals, "xml");` call.

### 2.9 — Fix skill-point reset bug on character creation

If you finish character creation with leftover, unallocated skill points, the original code calls `random_stats()`, which **resets all attributes to 1** before redistributing — wiping out points you'd already manually assigned and silently failing the save (an internal checksum mismatch blocks it). Add a non-destructive version that only spends the leftover points:

```actionscript
function auto_allocate_remaining_points(gladiator)
{
   while(gladiator.skillpoints > 0)
   {
      randomRoll = _root.randomBetween(1,100);
      randomMax = Math.ceil(gladiator.skillpoints / 3);
      randomAnt = _root.randomBetween(1,randomMax);
      gladiator.skillpoints -= randomAnt;
      if(randomRoll <= 20) { gladiator.strength += randomAnt; }
      if(randomRoll > 20 && randomRoll <= 40) { gladiator.vitality += randomAnt; }
      if(randomRoll > 40 && randomRoll <= 60) { gladiator.charisma += randomAnt; }
      if(randomRoll > 60 && randomRoll <= 80) { gladiator.intellect += randomAnt; }
      if(randomRoll > 80) { gladiator.agility += randomAnt; }
   }
   update_stats_text(_root.create_gladiator);
}
```

Then in `create_char_buttons()`'s `button_yes.onRelease`, change:

```actionscript
if(my_gladiator.skillpoints > 0)
{
   random_stats(my_gladiator);
}
```

to:

```actionscript
if(my_gladiator.skillpoints > 0)
{
   auto_allocate_remaining_points(my_gladiator);
}
```

---

## Step 3: Install SmartFoxServer PRO 1.x

The client (`it.gotoandplay.smartfoxserver.*` package) requires the **1.x line** of SmartFoxServer — **not** SFS2X or SFS3, which use an incompatible protocol and package namespace.

- Check SmartFoxServer's official site/forums for legacy 1.x downloads, or their support channels for obtaining an older version/license.
- You'll also need a **Java 6** runtime (e.g. Azul Zulu 6) to run it — modern Java (9+) throws a `java.nio.file` path-parsing error on startup, since it's much stricter than the `java.io`-based path handling this old server code assumes. Java 6 predates that stricter API entirely, avoiding the crash.

### Fixing the Java version used by the server

The server does **not** use `wrapper.conf`/`wrapper.exe` for normal console startup — it's launched directly via `start.bat` inside the `Server` folder, which calls `java` directly. Edit that file and change:

```bat
@java -cp "./;/;./lib/...
```

to point at your Java 6 install explicitly, e.g.:

```bat
@"C:\Java6\bin\java.exe" -cp "./;/;./lib/...
```

### Missing `logging.properties`

If your SFS install is missing `Server\logging.properties`, create it manually:

```properties
handlers = java.util.logging.FileHandler, java.util.logging.ConsoleHandler
.level = INFO

java.util.logging.FileHandler.pattern = logs/smartfox_log_%g.txt
java.util.logging.FileHandler.limit = 50000
java.util.logging.FileHandler.count = 5
java.util.logging.FileHandler.formatter = java.util.logging.SimpleFormatter

java.util.logging.ConsoleHandler.level = INFO
java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter
```

---

## Step 4: Configure the zone

Edit `Server\config.xml` and add a zone matching what the game client expects:

```xml
<Zone name="swords_sandals_multiplayer" uCountUpdate="true" maxUsers="4000" customLogin="false">
    <Rooms>
        <Room name="The Void" maxUsers="50" isPrivate="false" isTemp="false" autoJoin="true" uCountUpdate="true" />
        <Room name="inferno" maxUsers="4000" isPrivate="false" isTemp="false" autoJoin="false" />

        <Room name="Brawlers" maxUsers="50" isPrivate="false" isTemp="false" uCountUpdate="true" />
        <Room name="Fighters" maxUsers="50" isPrivate="false" isTemp="false" uCountUpdate="true" />
        <Room name="Knights" maxUsers="50" isPrivate="false" isTemp="false" uCountUpdate="true" />
        <Room name="Warriors" maxUsers="50" isPrivate="false" isTemp="false" uCountUpdate="true" />
    </Rooms>

    <Extensions>
        <extension name="ssmp_db" className="ssmp_db.as" type="script" />
    </Extensions>
</Zone>
```

**Important:** the hidden `The Void` and `inferno` rooms are required — the client uses them internally for lobby/room-switching logic. Don't remove them even though they're not visible Battle Halls.

Also raise the idle timeouts so players aren't disconnected while browsing menus/shops:

```xml
<MaxUserIdleTime>3600</MaxUserIdleTime>
<MaxSocketIdleTime>3600</MaxSocketIdleTime>
```

---

## Step 5: Install the server extension

1. Create the folder `Server\sfsExtensions\`.
2. Place `ssmp_db.as` (from this repo) inside it.
3. This extension provides:
   - Gladiator save/load (persisted to a local `gladiator_data.txt` file)
   - Hall of Fame leaderboard
   - Battle room start/ready handshake and move relay for combat

The extension auto-creates `gladiator_data.txt` in the server's working directory the first time someone saves a gladiator.

---

## Step 6: Run the game

1. Start the server (`start.bat`).
2. Download a standalone **Flash Player Projector** (e.g. from the Internet Archive's mirror of Adobe's official projector releases) since browsers no longer run Flash content.
3. If you hit a "Flash Player has stopped a potentially unsafe operation" security prompt, create a trust file:
   - Path: `%APPDATA%\Macromedia\Flash Player\#Security\FlashPlayerTrust\`
   - Create any `.cfg` file there containing the full path to the folder your patched SWF lives in.
4. Run the patched SWF via the projector. Keep the game's `assets/` folder in the same relative location it originally shipped in — the client loads arena/animation/item SWFs relative to its own path at runtime.

---

## Networking notes

- **LAN play**: set `ServerIP` in `config.xml` to `*`, and use your machine's LAN IP in the client patch (2.1).
- **Internet play**: port-forward TCP 9339 to your machine, and use your public IP in the client patch. If your ISP uses CGNAT, port forwarding won't work — use a mesh VPN like Tailscale or ZeroTier instead, which handles NAT traversal without any router configuration.

---

## Credits

Original game by 3rd Sense Australia Pty Ltd. This project is unaffiliated with and not endorsed by the original developers or Fizzy/gotoAndPlay. Server extension and setup/patch guide are original work produced through community reverse-engineering effort.
