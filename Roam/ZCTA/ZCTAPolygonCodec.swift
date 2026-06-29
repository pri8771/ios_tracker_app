import Foundation
import CoreLocation

/// Encodes/decodes polygon ring coordinates to/from a compact binary blob.
///
/// Encoding (must match `Scripts/build_zcta_bundle.py`):
/// - Each coordinate is quantized to `Int32` using scale `100000.0` (E5).
/// - Each point is stored as two little-endian `Int32` values: latE5 then lonE5.
/// - Rings are stored closed (first point repeated as last). `ensureClosed`
///   guarantees closure on encode; `decode` returns the closed ring.
enum ZCTAPolygonCodec {

    /// Quantization scale (1e5) — ~1.1 meter resolution at the equator.
    static let scale: Double = 100_000.0

    static let bytesPerPoint = 8 // 2 x Int32

    // MARK: - Encode

    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> Data {
        let closed = ensureClosed(coordinates)
        var data = Data(capacity: closed.count * bytesPerPoint)
        for c in closed {
            let latE5 = Int32((c.latitude * scale).rounded())
            let lonE5 = Int32((c.longitude * scale).rounded())
            appendLittleEndian(latE5, to: &data)
            appendLittleEndian(lonE5, to: &data)
        }
        return data
    }

    // MARK: - Decode

    /// Decodes a coordinate blob. Returns an empty array if the blob is malformed.
    static func decode(_ data: Data) -> [CLLocationCoordinate2D] {
        guard !data.isEmpty, data.count % bytesPerPoint == 0 else { return [] }
        let count = data.count / bytesPerPoint
        var coords = [CLLocationCoordinate2D]()
        coords.reserveCapacity(count)

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for i in 0..<count {
                let base = i * bytesPerPoint
                let latE5 = readLittleEndianInt32(raw, at: base)
                let lonE5 = readLittleEndianInt32(raw, at: base + 4)
                let lat = Double(latE5) / scale
                let lon = Double(lonE5) / scale
                guard lat.isFinite, lon.isFinite else { continue }
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return coords
    }

    // MARK: - Ring closure

    /// Returns a ring whose first and last coordinates are identical.
    static func ensureClosed(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard let first = coordinates.first, let last = coordinates.last else {
            return coordinates
        }
        if first.latitude == last.latitude && first.longitude == last.longitude {
            return coordinates
        }
        return coordinates + [first]
    }

    // MARK: - Byte helpers

    private static func appendLittleEndian(_ value: Int32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func readLittleEndianInt32(_ raw: UnsafeRawBufferPointer, at offset: Int) -> Int32 {
        var value: UInt32 = 0
        value |= UInt32(raw[offset])
        value |= UInt32(raw[offset + 1]) << 8
        value |= UInt32(raw[offset + 2]) << 16
        value |= UInt32(raw[offset + 3]) << 24
        return Int32(bitPattern: value)
    }
}
