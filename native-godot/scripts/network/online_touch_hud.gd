extends CanvasLayer
var actions: Array=[]
func is_action_at(at: Vector2) -> bool:
    for control in actions:
        if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(at):
            return true
    return false
