"""Final triangle budgets for repeated donor furniture, applied after beveling."""
def part_budget(key, name):
    if key.startswith('tribes_'):
        if name == 'ContouredLowerReceiver': return 1400
        if name == 'InstrumentReceiverShell': return 2400
    if key in ('doom_5', 'ut99_5') and name in ('Donor_stabilizer front', 'Donor_stabilizer mid'):
        return 1400
    if key in ('cs16_1', 'cs16_2', 'cs16_10') and name == 'SculptedPistolGrip': return 1200
    if key in ('doom_9', 'quake_9') and name == 'Donor_gun': return 9400
    return None

TARGETS = {}
for slot in (0, 1, 2, 3, 4, 5, 6, 7, 8, 11):
    TARGETS[f'tribes_{slot}'] = ['ContouredLowerReceiver'] + (['InstrumentReceiverShell'] if slot in (0, 6, 8, 11) else [])
for key in ('doom_5', 'ut99_5'): TARGETS[key] = ['Donor_stabilizer front', 'Donor_stabilizer mid']
for key in ('cs16_1', 'cs16_2', 'cs16_10'): TARGETS[key] = ['SculptedPistolGrip']
for key in ('doom_9', 'quake_9'): TARGETS[key] = ['Donor_gun']
