#!/usr/bin/env python3
"""OPTIONAL: bulk-upload every .ogg in Sounds/ to Roblox with Open Cloud and print the Config.Sounds block.

Setup (once):
  1. https://create.roblox.com/dashboard/credentials -> Create API key
     Access permissions: "Assets" -> Read + Write. Add your IP (or 0.0.0.0/0) to the allowed list.
  2. Find your numeric user ID (profile URL) or group ID (if the game is owned by a group).

Run (Python 3.8+, no extra packages):
  Windows:   set ROBLOX_API_KEY=xxxxx
             python upload_sounds.py --user-id 123456
  macOS/Lin: ROBLOX_API_KEY=xxxxx python3 upload_sounds.py --user-id 123456
  Group game: use --group-id 7890 instead of --user-id.

Output: sound_ids.txt + Config_Sounds_filled.lua (paste it over Config.Sounds in BOTH places).
Upload the sounds with the SAME account/group that owns the experience, otherwise the private
audio will not play in your game.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1"
ORDER = ["FlashlightOn", "FlashlightOff", "MonsterStep", "MonsterBreath", "MonsterScream", "MonsterSniff", "Sonar",
         "ChaseSting", "Ambience", "AmbienceMorgue", "AmbienceForest", "MenuMusic", "Heartbeat", "Static", "UIHover",
         "UIClick", "Pickup", "FuseInsert", "GeneratorOn", "GeneratorCrank", "GateOpen", "Purchase", "Teleport",
         "Whisper", "LightBuzz", "MetalBang", "Breathing", "Cloth", "Drip", "Wind", "Crow", "Bell",
         "FootstepConcrete", "FootstepWood", "FootstepGrass", "FootstepMetal", "Paper"]


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code == 429 or e.code >= 500:  # rate limited / transient
                time.sleep(2 + attempt * 3)
                continue
            raise SystemExit("HTTP %d for %s\n%s" % (e.code, url, msg))
    raise SystemExit("giving up on %s after retries" % url)


def upload(path, name, key, creator):
    meta = {
        "assetType": "Audio",
        "displayName": "Palata13_" + name,
        "description": "Palata 13 sound: " + name,
        "creationContext": {"creator": creator},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        audio = f.read()
    body = b"".join([
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % boundary).encode(),
        json.dumps(meta).encode(), b"\r\n",
        ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: audio/ogg\r\n\r\n"
         % (boundary, os.path.basename(path))).encode(),
        audio, ("\r\n--%s--\r\n" % boundary).encode(),
    ])
    op = request("POST", API + "/assets", key, body, "multipart/form-data; boundary=" + boundary)
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + "/operations/" + op_id, key)
    resp = op.get("response") or {}
    asset_id = resp.get("assetId")
    if not asset_id:
        raise SystemExit("no assetId for %s (moderation pending or error): %s" % (name, json.dumps(op)))
    return int(asset_id)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--user-id")
    g.add_argument("--group-id")
    ap.add_argument("--sounds", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sounds"))
    args = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        raise SystemExit("Set the ROBLOX_API_KEY environment variable first (see the top of this file).")
    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}
    ids_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sound_ids.txt")
    ids = {}
    if os.path.exists(ids_path):  # resume: skip what is already uploaded
        for line in open(ids_path, encoding="utf-8"):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                ids[k.strip()] = int(v)
    for name in ORDER:
        if name in ids:
            print("%-15s already uploaded: %d" % (name, ids[name]))
            continue
        path = os.path.join(args.sounds, name + ".ogg")
        if not os.path.exists(path):
            print("%-15s MISSING %s" % (name, path))
            continue
        ids[name] = upload(path, name, key, creator)
        print("%-15s -> %d" % (name, ids[name]))
        with open(ids_path, "w", encoding="utf-8") as f:
            for k in ORDER:
                if k in ids:
                    f.write("%s = %d\n" % (k, ids[k]))
    lua = ["Config.Sounds = {"] + ["\t%s = %d," % (k, ids.get(k, 0)) for k in ORDER] + ["}"]
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Config_Sounds_filled.lua")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lua) + "\n")
    print("\nWrote %s - paste it over Config.Sounds in ReplicatedStorage.Shared.Config (Lobby AND Game)." % out)


if __name__ == "__main__":
    sys.exit(main())
