import Foundation
import RealityKit

/// Entity data structure containing the Entity and its related information
public struct EntityData: Identifiable {
    /// Unique identifier
    public let id: UUID
    /// Entity object
    public let entity: Entity
    /// Entity name
    public let name: String
    
    /// Initialize a new EntityData
    /// - Parameters:
    ///   - entity: Entity object
    ///   - name: Entity name
    public init(entity: Entity, name: String) {
        self.id = UUID()
        self.entity = entity
        self.name = name
    }
    
    /// Initialize EntityData with specified ID
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - entity: Entity object
    ///   - name: Entity name
    public init(id: UUID, entity: Entity, name: String) {
        self.id = id
        self.entity = entity
        self.name = name
    }
}

/// Transform change callback type
public typealias TransformChangedCallback = (String, Transform) -> Void

/// Quaternion extension, provides Euler angle conversion
extension simd_quatf {
    func convertToEulerAngles() -> SIMD3<Float> {
        let qx = self.vector.x
        let qy = self.vector.y
        let qz = self.vector.z
        let qw = self.real
        
        // Roll (x-axis rotation)
        let sinr_cosp = 2 * (qw * qx + qy * qz)
        let cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
        let roll = atan2(sinr_cosp, cosr_cosp)
        
        // Pitch (y-axis rotation)
        let sinp = 2 * (qw * qy - qz * qx)
        let pitch: Float
        if abs(sinp) >= 1 {
            pitch = copysign(Float.pi / 2, sinp) // Use 90 degrees if out of range
        } else {
            pitch = asin(sinp)
        }
        
        // Yaw (z-axis rotation)
        let siny_cosp = 2 * (qw * qz + qx * qy)
        let cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
        let yaw = atan2(siny_cosp, cosy_cosp)
        
        return SIMD3<Float>(roll, pitch, yaw)
    }
} 