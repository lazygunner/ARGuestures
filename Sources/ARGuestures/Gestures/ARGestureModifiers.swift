import SwiftUI
import RealityKit

public struct ARGestureModifiers: ViewModifier {
    @ObservedObject var manager: ARGestureManager
    
    // Rotation configuration
    private let rotationAxis: RotationAxis3D
    private let rotationEnabled: Bool
    
    /// Initialize AR gestures modifier
    /// - Parameters:
    ///   - manager: AR gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y)
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    public init(
        manager: ARGestureManager, 
        rotationAxis: RotationAxis3D = .y,
        rotationEnabled: Bool = true
    ) {
        self.manager = manager
        self.rotationAxis = rotationAxis
        self.rotationEnabled = rotationEnabled
    }
    
    public func body(content: Content) -> some View {
        content
            .onDragAndRotate(
                manager: manager,
                rotationAxis: rotationAxis,
                rotationEnabled: rotationEnabled
            )
            .onScale(manager: manager)
    }
}

public extension View {
    /// Add AR interaction gestures including drag, rotate, and scale
    /// - Parameters:
    ///   - manager: AR gesture manager containing entities and state information
    ///   - rotationAxis: The axis to constrain rotation to (default is .y)
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    /// - Returns: View with AR gestures added
    func withARGestures(
        manager: ARGestureManager,
        rotationAxis: RotationAxis3D = .y,
        rotationEnabled: Bool = true
    ) -> some View {
        modifier(ARGestureModifiers(
            manager: manager,
            rotationAxis: rotationAxis,
            rotationEnabled: rotationEnabled
        ))
    }
    
    /// Add AR interaction gestures with drag only (no rotation) and scale
    /// - Parameter manager: AR gesture manager containing entities and state information
    /// - Returns: View with AR gestures added
    func withARDragAndScaleGestures(manager: ARGestureManager) -> some View {
        modifier(ARGestureModifiers(
            manager: manager,
            rotationEnabled: false
        ))
    }
} 