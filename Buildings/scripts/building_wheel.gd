extends Control

@export var bgColor : Color
@export var lineColor : Color
@export var highlightColor : Color
@export var lineWidth : int = 4
@export var outerRadius : int = 128
@export var innerRadius : int = 32

var select : int = -1

func _ready() -> void:
	hide()

func _draw() -> void:
	draw_circle(Vector2.ZERO, outerRadius, bgColor)
	draw_arc(Vector2.ZERO, innerRadius, 0, TAU, 128, lineColor, lineWidth, true)
	
	for i in FactoryGlobal.buildingArray.size():
		var rads = TAU * i / FactoryGlobal.buildingArray.size()
		var point = Vector2.from_angle(rads)
		draw_line(point * innerRadius, point * outerRadius, lineColor, lineWidth, true)
	
	var centerLabel : Label = Label.new()
	centerLabel.text = "Clear"
	add_child(centerLabel)
	centerLabel.position = Vector2(-innerRadius / 2.0, -innerRadius/ 2.0)
	
	for i in FactoryGlobal.buildingArray.size() + 1:
		var startRads = (TAU * (i - 1)) / FactoryGlobal.buildingArray.size()
		var endRads = (TAU * i) / FactoryGlobal.buildingArray.size()
		
		if select == -1:
			draw_circle(Vector2.ZERO, innerRadius, highlightColor)
		elif select == i:
			var pointsPerArc = 32
			var pointsInner = PackedVector2Array()
			var pointsOuter = PackedVector2Array()
			
			for j in range(pointsPerArc + 1):
				var angle = startRads + j * (endRads - startRads) / pointsPerArc
				pointsInner.append(innerRadius * Vector2.from_angle(TAU - angle))
				pointsOuter.append(outerRadius * Vector2.from_angle(TAU - angle))
				
			pointsOuter.reverse()
			draw_polygon(pointsInner + pointsOuter, PackedColorArray([highlightColor]))
			
		var midRads = (startRads + endRads) / 2.0 * -1
		var radiusMid = (innerRadius + outerRadius) / 2.0
		var drawPosition = outerRadius * Vector2.from_angle(midRads) - Vector2(30, 20)
		# Use this one once you have sprites
		#var drawPosition = radiusMid * Vector2.from_angle(midRads) + FactoryGlobal.HALF_CELL_SIZE
		# Remove this once you get real sprites
		var path = FactoryGlobal.buildingArray[i - 1].get_path()
		var placeholderLabel = Label.new()
		placeholderLabel.text = path.right(-path.rfind("/") - 1).left(-5)
		add_child(placeholderLabel)
		placeholderLabel.position = drawPosition

func _process(_delta: float) -> void:
	var cursorPosition = get_local_mouse_position()
	var cursorRadius = cursorPosition.length()
	
	if cursorRadius < innerRadius:
		select = -1
	else:
		var cursorRads = fposmod(cursorPosition.angle() * -1, TAU)
		select = ceil((cursorRads / TAU) * FactoryGlobal.buildingArray.size())
		
	queue_redraw()

func close() -> int:
	hide()
	if select == -1:
		return -1
	else:
		return select - 1
