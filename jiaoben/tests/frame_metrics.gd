extends RefCounted
## Passive diagnostics only. Samples real active Main frames; never advances
## physics, changes quality, or alters gameplay. Native runs give the baseline.
const Types=preload("res://contracts/contract_types.gd")
var samples: Dictionary = {}
var warming: Dictionary = {}
var peak_memory: int = 0
func observe(host: Variant, delta: float) -> void:
	if not is_instance_valid(host) or host.state==null or not host.is_physics_processing() or host.busy or host._paused(): return
	if host.state.ship().status != Types.ShipStatus.FLYING: return
	var window: Window = host.get_window()
	var key: String = str(window.size)+" / logical "+str(window.content_scale_size)
	warming[key] = int(warming.get(key,0))+1
	if int(warming[key])<=60: return
	if not samples.has(key): samples[key]={"frame_ms":[],"process_ms":[],"physics_ms":[],"draw_calls":[],"objects":[]}
	var bucket: Dictionary = samples[key]
	bucket.frame_ms.append(delta*1000.0)
	bucket.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	bucket.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	bucket.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	bucket.objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	peak_memory=maxi(peak_memory,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
func quantiles(values: Array) -> Dictionary:
	var ordered: Array=values.duplicate();ordered.sort()
	return {"samples":ordered.size(),"p50":ordered[int(floor((ordered.size()-1)*0.50))],"p95":ordered[int(floor((ordered.size()-1)*0.95))],"maximum":ordered[-1]}
func report() -> Dictionary:
	var layouts: Dictionary={};var count: int=0
	for key: String in samples:
		layouts[key]={}
		for metric: String in samples[key]:layouts[key][metric]=quantiles(samples[key][metric])
		count+=samples[key].frame_ms.size()
	return {"native":DisplayServer.get_name()!="headless","samples":count,"layouts":layouts,"warmup_frames_per_layout":60,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"physics_hz":Engine.physics_ticks_per_second,"peak_static_memory_bytes":peak_memory,"scope":"real active flying Main frames; excludes paused, staged and manually stepped test frames; no universal hardware performance claim"}
