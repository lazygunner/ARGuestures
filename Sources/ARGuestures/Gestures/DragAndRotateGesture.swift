import SwiftUI
import RealityKit

public struct DragAndRotateGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: ARGestureManager
    // Drag state
    @State private var isDraging = false
    @State private var isRotating = false
    @State private var dragStartPosition = SIMD3<Float>.zero
    @State private var lastRotation: simd_quatf?
    @State private var dragingEntityName: String = ""
    @State private var initialTransform: Transform?
    
    // Rotation axis configuration
    private let rotationAxis: RotationAxis3D
    private let rotationEnabled: Bool
    
    /// Initialize the drag and rotate gesture
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
            .gesture(
                DragGesture()
                    .simultaneously(
                        rotationEnabled ? 
                            RotateGesture3D(constrainedToAxis: rotationAxis) : 
                            nil
                    )
                    .targetedToAnyEntity()
                    .handActivationBehavior(.pinch) // Prevent moving objects by direct touch
                    .onChanged({ value in
                        let gestureEntity = value.entity
                        
                        // Use new method to quickly find entity
                        let (foundEntData, entName) = manager.findEntityData(from: gestureEntity)
                        
                        guard let foundEntData = foundEntData, !entName.isEmpty else {
                            if manager.isDebugEnabled {
                                print("Entity not found:\(value.entity)")
                            }
                            return
                        }
                        
                        let foundEntity = foundEntData.entity
                        // Rotation part
                        if rotationEnabled, let rotationValue = value.second {
                            
                            var rotation3D = rotationValue.rotation
                            rotation3D.vector.z = -rotation3D.vector.z
                            let rotationTransform = Transform(AffineTransform3D(rotation: rotationValue.rotation))
                            
                            var relativeRotation = rotationTransform
                            if let anchor = manager.referenceAnchor {
                                relativeRotation = anchor.convert(transform: rotationTransform, from: nil)
                            }
                            relativeRotation.translation = foundEntity.transform.translation
                            relativeRotation.scale = foundEntity.transform.scale

                            // Send transform message
                            manager.notifyTransformChanged(entName, relativeRotation)
                            
                            if !isRotating {
                                isRotating = true
                                if manager.isDebugEnabled {
                                    print("Starting rotation, entity rotation\(foundEntity.transform.rotation.convertToEulerAngles())")
                                }
                                lastRotation = foundEntity.transform.rotation
                                dragingEntityName = entName
                                initialTransform = foundEntity.transform
                            }
                            
                            if (lastRotation! == simd_quatf()) {
                                foundEntity.transform.rotation = rotationTransform.rotation
                                lastRotation = rotationTransform.rotation
                            } else {
                                foundEntity.transform.rotation = lastRotation! * rotationTransform.rotation
                            }
                            
                            // Send gesture callback
                            let angle = rotationValue.rotationAngle
                            manager.notifyGestureEvent(ARGestureInfo(
                                gestureType: .rotate,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: angle
                            ))
                                                    
                        } else if let transformValue = value.first {
                            // Movement part
                            let location3D = value.convert(transformValue.location3D, from: .local, to: .scene)
                            let translation3D = value.convert(transformValue.translation3D, from: .local, to: .scene)
                            
                            var transform = foundEntity.transform
                            // Set translation
                            transform.translation = SIMD3<Float>(x: Float(location3D.x),
                                                                 y: Float(location3D.y),
                                                                 z: Float(location3D.z))
                            
                            var relativePos = transform
                            if let anchor = manager.referenceAnchor {
                                relativePos = anchor.convert(transform: transform, from: nil)
                            }
                            relativePos.scale = transform.scale
                            relativePos.rotation = transform.rotation
                                                    
                            // Send transform message
                            manager.notifyTransformChanged(entName, relativePos)
                            
                            if !isDraging {
                                isDraging = true
                                dragStartPosition = foundEntity.position(relativeTo: nil)
                                dragingEntityName = entName
                                initialTransform = foundEntity.transform
                            }
                            let offset = SIMD3<Float>(x: Float(translation3D.x),
                                                      y: Float(translation3D.y),
                                                      z: Float(translation3D.z))
                            
                            let newPos = dragStartPosition + offset
                            foundEntity.setPosition(newPos, relativeTo: nil)
                            
                            // Send gesture callback
                            manager.notifyGestureEvent(ARGestureInfo(
                                gestureType: .drag,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: offset
                            ))
                            
                            // Check distance to table
                            var foundTable = false
                            for (id, anchor) in manager.planeAnchorsByID {
                                if anchor.classification == .table || anchor.classification == .floor {
                                    if !containing(pointToProject: foundEntity.transformMatrix(relativeTo: nil) , anchor) {
                                        continue
                                    }
                                    let yOffset = foundEntity.visualBounds(relativeTo: nil).extents.y / 2

                                    let planeMesh = manager.planeEntities[id]
                                    let newDistance = newPos.y - yOffset - (planeMesh?.transform.translation.y ?? 0)
                                    
                                    if anchor.classification == .floor {
                                        if foundTable {
                                            continue
                                        }
                                    }
                                    if newDistance < 0.3 {
                                        if anchor.classification == .table {
                                            foundTable = true
                                        }
                                        // Can place
                                        manager.placeAble = true
                                        manager.placementPosition = SIMD3<Float>(x: newPos.x, y: ((planeMesh?.transform.translation.y ?? 0) + yOffset), z: newPos.z)
                                        
                                        if let placementEntity = manager.placementInstructionEntity {
                                            placementEntity.position = SIMD3<Float>(x: newPos.x, y: (planeMesh?.transform.translation.y ?? 0) + 0.001, z: newPos.z)
                                            placementEntity.isEnabled = true
                                            
                                            // Scale 1 ~ 5, based on newDistance 0.4 ~ 0
                                            let scale = newDistance <= 0 ? 4 : 4 - (3 * (newDistance / 0.3))
                                            placementEntity.transform.scale = SIMD3<Float>(scale, 1, scale)
                                        }
                                    } else {
                                        // Don't place
                                        manager.placeAble = false
                                        manager.placementPosition = nil
                                        manager.placementInstructionEntity?.isEnabled = false
                                    }
                                }
                            }
                        }
                    })
                    .onEnded { _ in
                        isDraging = false
                        isRotating = false
                        
                        // Send gesture end callback
                        if let foundEntData = manager.getEntity(named: dragingEntityName) {
                            manager.notifyGestureEvent(ARGestureInfo(
                                gestureType: .gestureEnded,
                                entityName: dragingEntityName,
                                transform: foundEntData.entity.transform,
                                initialTransform: initialTransform
                            ))
                        }
                        
                        if manager.placeAble {
                            if manager.isDebugEnabled {
                                print("Can place")
                            }
                            manager.placementInstructionEntity?.isEnabled = false
                            if let foundEntData = manager.getEntity(named: dragingEntityName) {
                                manager.placeObject(foundEntData.entity)
                                
                                let transform = foundEntData.entity.transform
                                var relativePos = transform
                                if let anchor = manager.referenceAnchor {
                                    relativePos = anchor.convert(transform: transform, from: nil)
                                }
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                                    
                                // Send transform message
                                manager.notifyTransformChanged(dragingEntityName, relativePos)
                            }
                        }
                        
                        dragingEntityName = ""
                        initialTransform = nil
                    }
            )
    }
}

public extension View {
    /// Add drag and rotate gesture
    /// - Parameters:
    ///   - manager: AR gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y)
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    /// - Returns: View with added gestures
    func onDragAndRotate(
        manager: ARGestureManager,
        rotationAxis: RotationAxis3D = .y,
        rotationEnabled: Bool = true
    ) -> some View {
        modifier(DragAndRotateGestureViewModifier(
            manager: manager,
            rotationAxis: rotationAxis,
            rotationEnabled: rotationEnabled
        ))
    }
    
    /// Add drag-only gesture (no rotation)
    /// - Parameter manager: AR gesture manager
    /// - Returns: View with added gesture
    func onDragOnly(manager: ARGestureManager) -> some View {
        modifier(DragAndRotateGestureViewModifier(
            manager: manager,
            rotationEnabled: false
        ))
    }
} 