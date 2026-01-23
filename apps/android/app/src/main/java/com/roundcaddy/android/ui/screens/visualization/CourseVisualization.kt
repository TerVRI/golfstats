package com.roundcaddy.android.ui.screens.visualization

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.CameraPositionState
import com.google.maps.android.compose.Circle
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polygon
import com.google.maps.android.compose.rememberCameraPositionState
import com.roundcaddy.android.data.Coordinate
import com.roundcaddy.android.data.HoleData
import com.roundcaddy.android.data.PolygonFeature
import com.roundcaddy.android.data.TeeLocation
import com.roundcaddy.android.data.YardageMarker
import kotlin.math.absoluteValue
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

data class LayerVisibility(
    val fairway: Boolean = true,
    val green: Boolean = true,
    val rough: Boolean = true,
    val bunkers: Boolean = true,
    val water: Boolean = true,
    val trees: Boolean = false,
    val yardageMarkers: Boolean = true
)

@Composable
fun CourseMapView(
    holeData: List<HoleData>,
    selectedHole: Int,
    layers: LayerVisibility,
    showSatellite: Boolean
) {
    val hole = holeData.firstOrNull { it.holeNumber == selectedHole }
    val cameraPositionState = rememberCameraPositionState()
    val reference = referenceCoordinate(hole)

    LaunchedEffect(selectedHole) {
        val center = reference
        if (center != null) {
            cameraPositionState.position = cameraPositionState.position.copy(
                target = LatLng(center.lat, center.lon),
                zoom = 16f
            )
        }
    }

    val polygons = remember(hole) { buildPolygons(hole, reference) }
    val teeMarkers = remember(hole, reference) { buildTees(hole, reference) }
    val yardageMarkers = remember(hole, reference) { buildYardageMarkers(hole, reference) }
    val greenMarker = hole?.greenCenter?.let { normalizeCoordinate(it, reference) }

    GoogleMap(
        modifier = Modifier
            .fillMaxWidth()
            .height(380.dp),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(mapType = if (showSatellite) MapType.SATELLITE else MapType.NORMAL),
        uiSettings = MapUiSettings(compassEnabled = true, zoomControlsEnabled = false)
    ) {
        if (layers.fairway) {
            polygons.fairway?.let { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFF2E7D32), fillColor = Color(0x6632A852))
            }
        }
        if (layers.green) {
            polygons.green?.let { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFF43A047), fillColor = Color(0x8843A047))
            }
        }
        if (layers.rough) {
            polygons.rough?.let { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFF7CB342), fillColor = Color(0x3366BB6A))
            }
        }
        if (layers.bunkers) {
            polygons.bunkers.forEach { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFFFFB300), fillColor = Color(0x66FFD54F))
            }
        }
        if (layers.water) {
            polygons.water.forEach { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFF1E88E5), fillColor = Color(0x6642A5F5))
            }
        }
        if (layers.trees) {
            polygons.trees.forEach { polygon ->
                Polygon(points = polygon, strokeColor = Color(0xFF1B5E20), fillColor = Color(0x5533883A))
            }
        }
        teeMarkers.forEach { marker ->
            Marker(
                state = MarkerState(marker.location),
                title = marker.label,
                icon = BitmapDescriptorFactory.defaultMarker(marker.hue)
            )
        }
        greenMarker?.let {
            Marker(
                state = MarkerState(it),
                title = "Green",
                icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)
            )
        }
        if (layers.yardageMarkers) {
            yardageMarkers.forEach { marker ->
                Circle(
                    center = marker.location,
                    radius = 4.0,
                    fillColor = Color(0x99E53935),
                    strokeColor = Color(0xFFE53935)
                )
                Marker(state = MarkerState(marker.location), title = "${marker.distance}y")
            }
        }
    }
}

@Composable
fun CourseSchematicView(
    holeData: List<HoleData>,
    selectedHole: Int,
    layers: LayerVisibility
) {
    val hole = holeData.firstOrNull { it.holeNumber == selectedHole }
    val reference = referenceCoordinate(hole)
    val bounds = remember(hole, reference) { calculateBounds(hole, reference) }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("Schematic", style = MaterialTheme.typography.labelMedium)
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(280.dp)
            ) {
                if (hole == null) return@Canvas
                val width = size.width
                val height = size.height
                drawRect(color = Color(0xFFEFF7F1), size = Size(width, height))
                val translate = { coord: Coordinate ->
                    val normalized = normalizeCoordinate(coord, reference)
                    latLngToPoint(normalized, bounds, width, height)
                }

                fun drawPolygon(points: List<Coordinate>, fill: Color, stroke: Color) {
                    if (points.size < 3) return
                    val path = Path()
                    val first = translate(points.first())
                    path.moveTo(first.x, first.y)
                    points.drop(1).forEach { coord ->
                        val p = translate(coord)
                        path.lineTo(p.x, p.y)
                    }
                    path.close()
                    drawPath(path, color = fill)
                    drawPath(path, color = stroke, style = Stroke(width = 2f))
                }

                if (layers.fairway) hole.fairway?.let { drawPolygon(it, Color(0x6632A852), Color(0xFF2E7D32)) }
                if (layers.green) hole.green?.let { drawPolygon(it, Color(0x8843A047), Color(0xFF388E3C)) }
                if (layers.rough) hole.rough?.let { drawPolygon(it, Color(0x3366BB6A), Color(0xFF7CB342)) }
                if (layers.bunkers) hole.bunkers?.forEach { drawPolygon(it.polygon, Color(0x66FFD54F), Color(0xFFFFB300)) }
                if (layers.water) hole.waterHazards?.forEach { drawPolygon(it.polygon, Color(0x6642A5F5), Color(0xFF1E88E5)) }
                if (layers.trees) hole.trees?.forEach { drawPolygon(it.polygon, Color(0x5533883A), Color(0xFF1B5E20)) }

                hole.teeLocations?.forEach { tee ->
                    val point = translate(Coordinate(tee.lat, tee.lon))
                    drawCircle(color = teeColor(tee.tee), radius = 6f, center = point)
                }
                hole.greenCenter?.let {
                    val point = translate(it)
                    drawCircle(color = Color(0xFF2E7D32), radius = 8f, center = point)
                }
            }
        }
    }
}

data class MapPolygons(
    val fairway: List<LatLng>? = null,
    val green: List<LatLng>? = null,
    val rough: List<LatLng>? = null,
    val bunkers: List<List<LatLng>> = emptyList(),
    val water: List<List<LatLng>> = emptyList(),
    val trees: List<List<LatLng>> = emptyList()
)

data class MarkerInfo(val location: LatLng, val label: String, val hue: Float)
data class YardageInfo(val location: LatLng, val distance: Int)

private fun buildPolygons(hole: HoleData?, reference: Coordinate?): MapPolygons {
    if (hole == null) return MapPolygons()
    return MapPolygons(
        fairway = hole.fairway?.let { normalizeCoordinates(it, reference) },
        green = hole.green?.let { normalizeCoordinates(it, reference) },
        rough = hole.rough?.let { normalizeCoordinates(it, reference) },
        bunkers = hole.bunkers?.mapNotNull { feature ->
            if (feature.polygon.size < 3) null else normalizeCoordinates(feature.polygon, reference)
        } ?: emptyList(),
        water = hole.waterHazards?.mapNotNull { feature ->
            if (feature.polygon.size < 3) null else normalizeCoordinates(feature.polygon, reference)
        } ?: emptyList(),
        trees = hole.trees?.mapNotNull { feature ->
            if (feature.polygon.size < 3) null else normalizeCoordinates(feature.polygon, reference)
        } ?: emptyList()
    )
}

private fun buildTees(hole: HoleData?, reference: Coordinate?): List<MarkerInfo> {
    return hole?.teeLocations?.mapNotNull { tee ->
        normalizeCoordinate(Coordinate(tee.lat, tee.lon), reference)?.let { latLng ->
            MarkerInfo(latLng, tee.tee.uppercase(), teeHue(tee.tee))
        }
    } ?: emptyList()
}

private fun buildYardageMarkers(hole: HoleData?, reference: Coordinate?): List<YardageInfo> {
    return hole?.yardageMarkers?.mapNotNull { marker ->
        normalizeCoordinate(Coordinate(marker.lat, marker.lon), reference)?.let { latLng ->
            YardageInfo(latLng, marker.distance)
        }
    } ?: emptyList()
}

private fun teeHue(tee: String): Float {
    return when (tee.lowercase()) {
        "black" -> BitmapDescriptorFactory.HUE_VIOLET
        "blue" -> BitmapDescriptorFactory.HUE_BLUE
        "white" -> BitmapDescriptorFactory.HUE_AZURE
        "gold" -> BitmapDescriptorFactory.HUE_YELLOW
        "red" -> BitmapDescriptorFactory.HUE_RED
        else -> BitmapDescriptorFactory.HUE_BLUE
    }
}

private fun teeColor(tee: String): Color {
    return when (tee.lowercase()) {
        "black" -> Color.Black
        "blue" -> Color(0xFF1E88E5)
        "white" -> Color.White
        "gold" -> Color(0xFFFFD54F)
        "red" -> Color(0xFFE53935)
        else -> Color(0xFF1E88E5)
    }
}

private fun referenceCoordinate(hole: HoleData?): Coordinate? {
    return hole?.greenCenter ?: hole?.teeLocations?.firstOrNull()?.let { Coordinate(it.lat, it.lon) }
}

private fun normalizeCoordinates(points: List<Coordinate>, reference: Coordinate?): List<LatLng> {
    if (reference == null) {
        return points.map { LatLng(it.lat, it.lon) }
    }
    val original = points.map { LatLng(it.lat, it.lon) }
    val swapped = points.map { LatLng(it.lon, it.lat) }
    val originalDistance = averageDistance(original, reference)
    val swappedDistance = if (swapped.all { isValid(it) }) averageDistance(swapped, reference) else originalDistance
    val chosen = if (swappedDistance < originalDistance) swapped else original
    return chosen
}

private fun normalizeCoordinate(point: Coordinate, reference: Coordinate?): LatLng? {
    if (reference == null) return LatLng(point.lat, point.lon)
    val original = LatLng(point.lat, point.lon)
    val swapped = LatLng(point.lon, point.lat)
    if (!isValid(swapped)) return original
    val originalDistance = distanceMeters(reference.lat, reference.lon, original.latitude, original.longitude)
    val swappedDistance = distanceMeters(reference.lat, reference.lon, swapped.latitude, swapped.longitude)
    return if (swappedDistance < originalDistance) swapped else original
}

private fun isValid(latLng: LatLng): Boolean {
    return latLng.latitude.absoluteValue <= 90 && latLng.longitude.absoluteValue <= 180
}

private fun averageDistance(points: List<LatLng>, reference: Coordinate): Double {
    if (points.isEmpty()) return 0.0
    val total = points.sumOf { distanceMeters(reference.lat, reference.lon, it.latitude, it.longitude) }
    return total / points.size
}

private fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val r = 6371000.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2) * sin(dLat / 2) +
        cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2)
    val c = 2 * kotlin.math.atan2(sqrt(a), sqrt(1 - a))
    return r * c
}

private data class Bounds(
    val minLat: Double,
    val maxLat: Double,
    val minLon: Double,
    val maxLon: Double
) {
    val width: Double get() = (maxLon - minLon).coerceAtLeast(0.000001)
    val height: Double get() = (maxLat - minLat).coerceAtLeast(0.000001)
}

private fun calculateBounds(hole: HoleData?, reference: Coordinate?): Bounds {
    if (hole == null) return Bounds(0.0, 0.0, 0.0, 0.0)
    val all = mutableListOf<Coordinate>()
    hole.teeLocations?.forEach { all.add(Coordinate(it.lat, it.lon)) }
    hole.greenCenter?.let { all.add(it) }
    hole.fairway?.let { all.addAll(it) }
    hole.green?.let { all.addAll(it) }
    hole.bunkers?.forEach { all.addAll(it.polygon) }
    hole.waterHazards?.forEach { all.addAll(it.polygon) }
    hole.trees?.forEach { all.addAll(it.polygon) }

    val normalized = if (reference == null) {
        all
    } else {
        val originals = all
        val swapped = all.map { Coordinate(it.lon, it.lat) }
        val originalDistance = averageDistance(originals.map { LatLng(it.lat, it.lon) }, reference)
        val swappedDistance = averageDistance(swapped.map { LatLng(it.lat, it.lon) }, reference)
        if (swappedDistance < originalDistance) swapped else originals
    }

    val minLat = normalized.minOfOrNull { it.lat } ?: 0.0
    val maxLat = normalized.maxOfOrNull { it.lat } ?: 0.0
    val minLon = normalized.minOfOrNull { it.lon } ?: 0.0
    val maxLon = normalized.maxOfOrNull { it.lon } ?: 0.0
    return Bounds(minLat, maxLat, minLon, maxLon)
}

private fun latLngToPoint(coord: LatLng?, bounds: Bounds, width: Float, height: Float): Offset {
    if (coord == null) return Offset(width / 2, height / 2)
    val x = ((coord.longitude - bounds.minLon) / bounds.width) * width
    val y = height - ((coord.latitude - bounds.minLat) / bounds.height) * height
    val padding = min(width, height) * 0.08f
    return Offset(
        x = x.coerceIn(padding, width - padding),
        y = y.coerceIn(padding, height - padding)
    )
}

private fun latLngToPoint(coord: Coordinate, bounds: Bounds, width: Float, height: Float): Offset {
    return latLngToPoint(LatLng(coord.lat, coord.lon), bounds, width, height)
}
