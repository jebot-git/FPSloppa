# CQ moderator controls

Press **F8** or click **Moderator** after joining. Enter the master password to unlock controls for one hour. The password field is masked and cleared after submission; the session token stays in memory. Closing the menu closes its drop-downs. **Lock moderator controls** ends the session.

- Teleport to an online district, teleport beside a selected player, or bring that player beside you.
- Hold **F9** or the broadcast button for global voice. All connected players hear it across teams and regions; a visible GLOBAL indicator identifies the speaker. Release to stop. Microphone capture opens only while held and stops on focus loss, menu close or after 30 seconds. Only one moderator broadcasts at a time.
- Teleports retain the 16-player district limit, require living residents and use floor/capsule collision checks. Unavailable, full or blocked destinations fail without removing the player. These controls bypass campaign gate locks, but do not revive players or grant weapons.

## Configure the master

From the source tree or server deployment archive:

```sh
./set-moderator-password.sh /private/cq/live.cfg
# Prepare/redeploy after updating the inventory:
./prepare-deployment.sh --cfg /private/cq/live.cfg --output /private/cq/generated
./deploy-components.sh --output /private/cq/generated
```

The hidden prompt stores a salted scrypt verifier as `moderator_password_hash` in `[cluster]`. The deployment generator copies it only into master `[cq]` configurations. You can instead update the deployed master directly with `./set-moderator-password.sh config/node.cfg`, then restart `cq.service`. For multiple masters, copy the same verifier to every master and restart them all. A changed verifier invalidates existing sessions; an empty verifier disables moderation. `--disable` clears it. No default password is shipped.

All moderator actions are checked by the master against the authenticated player and temporary grant. Login attempts are throttled; the last 64 authorized actions are kept in the durable campaign state. Passwords and session tokens are excluded from public status and player profiles. Gameplay and password traffic use the deployment's private WireGuard network.

Voice uses one bounded 16 kHz mono PCM16 stream: 100 ms frames, ten frames/s, short receive queues and no media persistence on the master. Regional gateways fan out audio, while the master grants the current speaker lease. Budget roughly 0.35 Mbit/s per listener including JSON/base64 before transport overhead, about 44 Mbit/s at 128 listeners during an announcement. This is an announcement channel, not the district team-radio channel.
