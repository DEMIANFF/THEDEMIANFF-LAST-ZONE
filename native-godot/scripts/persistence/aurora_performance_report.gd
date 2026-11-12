extends RefCounted
## Grounded, device-local benchmark only. Never populates fantasy FPS metrics.
## One write per finished match; no constant disk I/O during Android play.
const PATH: String="user://aurora_performance_report.cfg"


static func latest() -> Dictionary:
    var cfg:=ConfigFile.new()
    if cfg.load(PATH)!=OK:
        return {}
    return {
        "participants":int(cfg.get_value("run","participants",0)),
        "frames":int(cfg.get_value("run","frames",0)),
        "average_fps":float(cfg.get_value("run","average_fps",0.0)),
        "low10_fps":float(cfg.get_value("run","low10_fps",0.0)),
        "min_fps":float(cfg.get_value("run","min_fps",0.0)),
        "seconds":int(cfg.get_value("run","seconds",0)),
        "completed":bool(cfg.get_value("run","completed",false))
    }


static func record(participants: int,samples: Array[float],
        elapsed: float,complete: bool) -> Error:
    if samples.is_empty() or participants not in [9,20,30]:
        return ERR_INVALID_PARAMETER
    var valid: Array[float]=[]
    for value in samples:
        if is_finite(value) and value>0.0 and value<360.0:
            valid.append(value)
    if valid.is_empty():
        return ERR_INVALID_DATA
    valid.sort()
    var total: float=0.0
    for value in valid:
        total+=value
    var low: int=clampi(int(floor((valid.size()-1)*.10)),0,valid.size()-1)
    var cfg:=ConfigFile.new()
    cfg.set_value("run","participants",participants)
    cfg.set_value("run","frames",valid.size())
    cfg.set_value("run","average_fps",snappedf(total/valid.size(),.1))
    cfg.set_value("run","low10_fps",snappedf(valid[low],.1))
    cfg.set_value("run","min_fps",snappedf(valid[0],.1))
    cfg.set_value("run","seconds",roundi(elapsed))
    cfg.set_value("run","completed",complete)
    return cfg.save(PATH)
