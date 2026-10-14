extends RefCounted
## One serial Store owner. The worker never touches the active scene tree.
var thread := Thread.new()
var mutex := Mutex.new()
var prepared := Semaphore.new()
var store: XJGameStore
var pending: Dictionary = {}
var accepted: bool = false
var cancelled: bool = false

func start(database: XJGameStore, operation: Callable) -> Error:
	store = database
	return thread.start(operation)

func prepare(candidate: XJRuntimeState) -> bool:
	mutex.lock()
	if cancelled:
		mutex.unlock()
		return false
	pending = {"state": candidate, "catalog": store.staging_catalog}
	mutex.unlock()
	prepared.wait()
	mutex.lock()
	var result: bool = accepted and not cancelled
	mutex.unlock()
	return result

func take_preparation() -> Dictionary:
	mutex.lock()
	var result: Dictionary = pending
	pending = {}
	mutex.unlock()
	return result

func accept_preparation(value: bool) -> void:
	mutex.lock()
	accepted = value
	mutex.unlock()
	prepared.post()

func finish() -> Variant:
	return thread.wait_to_finish()

func shutdown() -> void:
	# A teardown must release a waiting prepare before joining, then close Store.
	mutex.lock()
	cancelled = true
	mutex.unlock()
	prepared.post()
	if thread.is_started(): thread.wait_to_finish()
