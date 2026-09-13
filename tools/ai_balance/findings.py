"""Interpret observed trials; keep causal claims separate from measured facts."""
from collections import defaultdict


def paragraphs(mode, rows, supplies):
    if not rows:
        return []
    if mode == 'koth':
        basic = sum(r['basic_loadout_deaths'] for r in rows)
        deaths = sum(r['deaths'] for r in rows)
        audit = supplies.get('02-supplies', {}).get('rows', [])
        efficient = sum(0 < r['detour_ratio'] <= 1.5 for r in audit)
        return [
            f"Blue won {sum(r['score'][1] > r['score'][0] for r in rows)}/{len(rows)} rounds, including swapped rosters. "
            f"{basic}/{deaths} deaths ({basic/deaths:.1%}) occurred with only basic ranged equipment. "
            "This flags a side-dependent bottleneck in these AI trials; it is not a human win-rate estimate.",
            f"The supply audit found navigation and clear pickup capsules on all {len(audit)} spawn–weapon routes; "
            f"only {efficient} cost at most 1.5× the direct hill route. Reachability alone therefore does not establish useful equipment access. "
            "Next: compare side-route equipment and approach coverage in an experimental variant, with human confirmation before changing the hill radius.",
        ]
    if mode == 'ctf':
        carriers = [c for r in rows for c in r['carrier_progress']]
        audit = supplies.get('03-supplies', {}).get('rows', [])
        basic = sum(r['basic_loadout_deaths'] for r in rows)
        deaths = sum(r['deaths'] for r in rows)
        text = [f"{basic}/{deaths} deaths ({basic/deaths:.1%}) retained only starting ranged equipment. "
                f"All {len(audit)} spawn–weapon routes passed navigation and pickup-clearance checks; "
                f"{sum(0 < r['detour_ratio'] <= 1.5 for r in audit)} cost at most 1.5× the direct flag approach."]
        if carriers:
            durations = [c['end']-c['take'] for c in carriers]
            rocket_ammo = [c['equipment']['ammo'][2] for c in carriers if 6 in c['equipment']['owned']]
            text.append(f"Carrier episodes lasted {min(durations):.2f}–{max(durations):.2f}s; "
                        f"the greatest reduction in straight-line distance to home was {max(c['start_distance']-c['best_distance'] for c in carriers):.2f} m. "
                        f"Rocket-launcher owners had these rocket-ammo counts at the take: {rocket_ammo}. "
                        "Owning a weapon therefore does not establish sustained ammunition access.")
        text.append("Confirmed source issue: the frozen `deathmatch/bots.gd` uses weapon IDs above 2 as its better-equipment predicate. "
                    "UT99 starts with translocator ID 11, which suppresses the nearby new-weapon boost; Bio Rifle ID 1 also receives the lower unowned-weapon value. "
                    "This contradicts a combat-equipment interpretation of the rule. Its contribution to failed captures remains a hypothesis. "
                    "Next: compare a profile-aware equipment predicate and ammo acquisition using the same matrix before reducing defender strength or shortening the map.")
        return text
    if mode == 'as':
        first = [r['assault_progress'][-1]['first_time'] for r in rows]
        returns = sum(r['assault_progress'][-1]['stage'] == 2 for r in rows)
        wins = [sum(r['score'][team] > r['score'][1-team] for r in rows) for team in (0, 1)]
        return [f"All {len(rows)} full matches finished normally. First attacks completed in {min(first):.1f}–{max(first):.1f}s "
                f"against a six-minute budget; {returns} return attacks completed inside the time to beat, and {len(rows)-returns} timed out. "
                f"Wins split {wins[0]}–{wins[1]} between red and blue. This does not reproduce an objective that is impossible to complete with the intended attack budget.",
                "No attacker water exposure was observed. These matches compare natural equipment acquisition but do not exercise the alternate water entrance. "
                "Retain objective health; a separately guided alternate-entry traversal and then tactical comparison remain needed."]
    if mode == 'tf':
        damage, exposure, captures = defaultdict(float), defaultdict(float), defaultdict(int)
        for r in rows:
            for k, v in r['class_combat_damage'].items():
                damage[k] += v
            for k, v in r['active_class_seconds'].items():
                exposure[k] += v
            for c in r['carrier_progress']:
                if c['ended'] == 'capture':
                    captures[c['equipment']['class']] += 1
        table = ['| Class | Opponent combat damage | Approx. active bot-minutes | Damage / active minute | Captures |',
                 '| --- | ---: | ---: | ---: | ---: |']
        for k in sorted(exposure):
            minutes = exposure[k] / 60
            table.append(f'| {k} | {damage[k]:.0f} | {minutes:.2f} | {damage[k]/minutes:.1f} | {captures[k]} |')
        return ['Both teams use the same composition within a round. These are composition-specific behavior checks, not one class mix competing against another. '
                'Capture credit follows the observed carrier episode. Combat excludes voluntary, environmental, self and friendly damage.',
                '\n'.join(table),
                'Retain specialization. Per-active-minute damage remains affected by class roles, encounters and approximate exposure sampling; it does not justify a class nerf.']
    if mode == 'cc':
        damage = defaultdict(int)
        for r in rows:
            for k, v in r['damage_categories'].items():
                damage[k] += v
        total = sum(damage.values())
        return [f"Hunger accounts for {damage['hunger']/max(1,total):.1%} of all recorded damage. "
                "Use opponent combat alone for weapon comparisons; report hunger separately as mode pressure."]
    if mode == 'if':
        text = ['Ordinary damage totals are not a useful activity measure for this mode. Use the recorded freeze, rescue and scored-round events; '
                'successful thaws establish that rescue behavior occurred, not that every reachable rescue was attempted.']
        for r in rows:
            event = r['last_freeze_mode_event']
            if event:
                quiet = r['simulated_seconds'] - event['time']
                text.append(f"{r['case']}: last freeze/thaw/round-score event at {event['time']:.1f}s, "
                            f"followed by {quiet:.1f}s without another such event; {r['shots']} shots in total. "
                            f"Planner recorded {r['teamplay'].get('unreachable_goals', 0)} unreachable-goal attempts "
                            f"in {r['teamplay'].get('route_queries', 0)} route queries (repeated attempts, not unique locations).")
        text.append('Long event-free intervals are an engagement/recovery concern. Inspect failed qsrc_dm6 routes and rescue access before treating these trials as healthy sustained play. '
                    'Team-colored roster swaps on this deathmatch layout can reproduce identical spatial play; they are not independent evidence.')
        return text
    return []
