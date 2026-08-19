import Foundation
import Compression

nonisolated enum GzipError: Error, LocalizedError {
    case invalidHeader
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "The downloaded report segment was not valid gzip data."
        case .decompressionFailed: return "Failed to decompress the report segment."
        }
    }
}

/// Minimal gzip reader: strips the gzip container and inflates the raw DEFLATE
/// stream using Apple's Compression framework (COMPRESSION_ZLIB decodes raw deflate).
nonisolated enum Gzip {
    static func decompress(_ data: Data) throws -> Data {
        guard data.count > 18 else { throw GzipError.invalidHeader }
        let bytes = [UInt8](data)
        guard bytes[0] == 0x1f, bytes[1] == 0x8b else { throw GzipError.invalidHeader }

        let flg = bytes[3]
        var offset = 10
        if flg & 0x04 != 0 { // FEXTRA
            guard offset + 2 <= bytes.count else { throw GzipError.invalidHeader }
            let xlen = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flg & 0x08 != 0 { // FNAME
            while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x10 != 0 { // FCOMMENT
            while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flg & 0x02 != 0 { // FHCRC
            offset += 2
        }
        guard offset < data.count - 8 else { throw GzipError.invalidHeader }
        let deflateData = data.subdata(in: offset..<(data.count - 8))

        var bufferSize = max(deflateData.count * 4, 65536)
        let maxBufferSize = 1_000_000_000

        while bufferSize <= maxBufferSize {
            var destinationBuffer = [UInt8](repeating: 0, count: bufferSize)
            let decodedSize = deflateData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
                guard let srcBase = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    &destinationBuffer, bufferSize,
                    srcBase, deflateData.count,
                    nil, COMPRESSION_ZLIB
                )
            }
            if decodedSize > 0 {
                return Data(destinationBuffer[0..<decodedSize])
            }
            bufferSize *= 4
        }
        throw GzipError.decompressionFailed
    }
}
