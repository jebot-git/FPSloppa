extends Node
## Executed in a tiny test PCK by the same audited console runtime as the server.
func _ready() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var http:=HTTPRequest.new();add_child(http)
	http.timeout=3;http.body_size_limit=4096;http.max_redirects=0;http.use_threads=true
	var failures: Array=[]
	http.request(args[0]+"/v1/servers")
	var untrusted: Array=await http.request_completed
	if untrusted[0]==HTTPRequest.RESULT_SUCCESS:failures.append("Untrusted certificate accepted")
	var ca:=X509Certificate.new()
	if ca.load(args[1])!=OK:failures.append("Cannot load test CA")
	http.set_tls_options(TLSOptions.client(ca))
	http.request(args[0]+"/v1/servers")
	var trusted: Array=await http.request_completed
	if trusted[0]!=HTTPRequest.RESULT_SUCCESS or trusted[1]!=200:failures.append("Trusted HTTPS directory request failed")
	http.request(args[0].replace("127.0.0.1","localhost")+"/v1/servers")
	var mismatch: Array=await http.request_completed
	if mismatch[0]==HTTPRequest.RESULT_SUCCESS:failures.append("Wrong certificate hostname accepted")
	print("DISCOVERY_TLS_RESULT ",JSON.stringify({"failures":failures,"untrusted_result":untrusted[0],"trusted_result":trusted[0],"hostname_result":mismatch[0]}))
	http.queue_free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
