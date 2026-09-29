extends SceneTree
const Deadline=preload("res://tools/tribes/capture_deadline.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():
	var watch=Deadline.new();watch.observe(599.99,[0,0])
	check(not watch.expired(599.99),"A scoreless match gets its full ten game minutes")
	check(watch.expired(600),"A scoreless match stops at ten game minutes")
	watch.observe(600.02,[1,0]);check(watch.expired(600.02),"A late capture cannot rescue a missed deadline")
	for team in [0,1]:
		watch=Deadline.new();var scores: Array=[0,0];scores[team]=1;watch.observe(600,scores)
		check(not watch.expired(600),"Either team's capture at the deadline counts: %d"%team)
		watch.pickup(650);watch.observe(1800,scores);check(not watch.expired(1800) and watch.first_capture_seconds==600,"A pickup after capture satisfies that capture's activity window")
	watch=Deadline.new();watch.observe(120,[1,0]);watch.observe(240,[1,1])
	check(watch.first_capture_seconds==120,"Later captures preserve the original timestamp")
	check(not watch.expired(839.99),"Post-capture inactivity gets all ten game minutes")
	check(watch.reason(840)=="no_pickup_after_capture_600s","No pickup after the last capture terminates at 600 game seconds")
	watch=Deadline.new();watch.pickup(100);watch.observe(120,[1,0])
	check(watch.expired(720),"The pickup that led to a capture cannot satisfy its next activity window")
	watch=Deadline.new();watch.observe(120,[1,0]);watch.pickup(720)
	check(not watch.expired(720),"A pickup exactly at the post-capture deadline counts")
	watch.observe(730,[1,1]);check(watch.expired(1330),"Each subsequent capture starts a new pickup window")
	watch=Deadline.new();watch.observe(120,[1,0]);watch.pickup(720.02)
	check(watch.expired(720.02),"A late pickup cannot rescue an already missed activity deadline")
	watch=Deadline.new();watch.pickup(590)
	check(watch.reason(600)=="no_capture_600s","Pickups do not waive the initial capture cutoff")
	print("ST_CAPTURE_DEADLINE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
