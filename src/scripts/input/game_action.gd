class_name GameAction
extends RefCounted

enum Type {
	NONE,
	DRAG_PRESS,
	DRAG_RELEASE,
	DRAG_MOVE,
	SHOP_BUY,
	REROLL,
	BUY_EXP,
	START_BATTLE,
	GO_BACK,
}

var type: Type = Type.NONE
var screen_position: Vector2 = Vector2.ZERO
var shop_slot: int = -1


static func drag_press(screen_position: Vector2) -> GameAction:
	var action := GameAction.new()
	action.type = Type.DRAG_PRESS
	action.screen_position = screen_position
	return action


static func drag_release(screen_position: Vector2) -> GameAction:
	var action := GameAction.new()
	action.type = Type.DRAG_RELEASE
	action.screen_position = screen_position
	return action


static func drag_move(screen_position: Vector2) -> GameAction:
	var action := GameAction.new()
	action.type = Type.DRAG_MOVE
	action.screen_position = screen_position
	return action


static func shop_buy(slot_index: int) -> GameAction:
	var action := GameAction.new()
	action.type = Type.SHOP_BUY
	action.shop_slot = slot_index
	return action


static func simple(action_type: Type) -> GameAction:
	var action := GameAction.new()
	action.type = action_type
	return action
