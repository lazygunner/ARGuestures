# ARGuestures

ARGuestures is a Swift package that provides AR interaction gesture capabilities for Entities in VisionOS applications.

## Features

- Drag: Move 3D objects
- Rotate: Rotate 3D objects (supports customizable rotation axis)
- Scale: Adjust 3D object size
- Plane detection: Support for placing objects on detected planes
- Gesture callbacks: Monitor gesture events and get change values
- Debug mode: Print detailed gesture information
- Efficient entity lookup: Use mapping tables to quickly locate gesture-interacted entities
- Customizable rotation: Specify rotation axis or disable rotation

## Requirements

- visionOS 1.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/lazygunner/ARGuestures.git", from: "1.0.0")
]
```

## Usage

### Initialize ARGestureManager

```swift
import ARGuestures
import RealityKit
import SwiftUI

// Create anchor and instruction entities
let referenceAnchor = Entity()
let placementInstructionEntity = Entity()

// Initialize gesture manager (with debug mode enabled)
let gestureManager = ARGuestures.createManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity,
    isDebugEnabled: true  // Enable debug output
)

// Or initialize directly
let manager = ARGestureManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity
)

// Add 3D model entity
let modelEntity = try! await Entity.load(named: "toy_robot")
gestureManager.addEntity(modelEntity, name: "robot")

// Set transform callback
gestureManager.setTransformChangedCallback { (entityName, transform) in
    print("Entity \(entityName) transformed to: \(transform)")
}

// Set gesture callback (monitor all gesture events)
gestureManager.setGestureCallback { gestureInfo in
    switch gestureInfo.gestureType {
    case .drag:
        print("Dragging: \(gestureInfo.entityName)")
    case .rotate:
        print("Rotating: \(gestureInfo.entityName)")
    case .scale:
        if let magnification = gestureInfo.changeValue as? Float {
            print("Scaling: \(gestureInfo.entityName), scale factor: \(magnification)")
        }
    case .gestureEnded:
        print("Gesture ended: \(gestureInfo.entityName)")
    }
}
```

### Enable or Disable Debug Mode

```swift
// Enable debug mode
gestureManager.setDebugEnabled(true)

// Disable debug mode
gestureManager.setDebugEnabled(false)

// Direct setting
gestureManager.isDebugEnabled = true
```

### Add Gesture Support to Views

```swift
import ARGuestures
import RealityKit
import SwiftUI

struct ContentView: View {
    @StateObject var gestureManager: ARGestureManager
    
    var body: some View {
        RealityView { content in
            // Set up scene content
            if let anchor = gestureManager.referenceAnchor {
                content.add(anchor)
            }
            
            // Add model
            if let entity = gestureManager.entities.first?.entity {
                content.add(entity)
            }
            
            // Add placement indicator
            if let placementEntity = gestureManager.placementInstructionEntity {
                content.add(placementEntity)
            }
        }
        // Default (Y-axis rotation)
        .withARGestures(manager: gestureManager)
        
        // Or specify rotation axis
        .withARGestures(
            manager: gestureManager,
            rotationAxis: .x  // Rotate around X-axis
        )
        
        // Or disable rotation completely
        .withARGestures(
            manager: gestureManager,
            rotationEnabled: false
        )
        
        // Or use the convenience method for drag and scale only
        .withARDragAndScaleGestures(manager: gestureManager)
    }
}
```

### Use Individual Gestures

If you only need specific gesture functionality, you can use them individually:

```swift
// Only use drag and rotate gestures (Y-axis rotation)
myView.onDragAndRotate(manager: gestureManager)

// Specify rotation axis
myView.onDragAndRotate(
    manager: gestureManager,
    rotationAxis: .z  // Rotate around Z-axis
)

// Only use drag gesture (no rotation)
myView.onDragOnly(manager: gestureManager)

// Only use scale gesture
myView.onScale(manager: gestureManager)
```

## Managing Entities

ARGestureManager provides various methods to manage entities:

```swift
// Add entity
let entityData = gestureManager.addEntity(newEntity, name: "newEntity")

// Get entity
if let entity = gestureManager.getEntity(named: "robot") {
    // Use found entity...
}

// Remove entity
gestureManager.removeEntity(named: "robot")

// Find main entity from interacted entity
let (entityData, entityName) = gestureManager.findEntityData(from: interactedEntity)
```

## Efficient Entity Lookup

ARGuestures uses a multi-layered caching mechanism to provide efficient entity lookup:

1. **Entity mapping table**: All registered entities are stored in a hash table with O(1) time complexity
2. **Component mapping**: Creates mapping relationships for the entity and all its child entities, supporting quick lookup
3. **Hierarchy traversal**: For complex structures, can search up the parent chain
4. **Fallback system**: For special cases, provides complete recursive search as a fallback solution

This multi-layered lookup mechanism ensures that gesture interactions have optimal performance, maintaining a smooth user experience even in complex scenes.

## Gesture Monitoring

Through gesture callbacks, you can monitor all gesture events and get detailed information:

```swift
gestureManager.setGestureCallback { info in
    // Gesture type
    let gestureType = info.gestureType
    
    // Entity name
    let entityName = info.entityName
    
    // Current transform
    let transform = info.transform
    
    // Initial transform (at start)
    if let initialTransform = info.initialTransform {
        // Calculate change amount
        let translationDiff = transform.translation - initialTransform.translation
        print("Position offset: \(translationDiff)")
    }
    
    // Specific change value
    if let changeValue = info.changeValue {
        if info.gestureType == .scale {
            // Scale factor
            let magnification = changeValue as! Float
            print("Scale factor: \(magnification)")
        } else if info.gestureType == .rotate {
            // Rotation angle
            let angle = changeValue as! Float
            print("Rotation angle: \(angle)")
        }
    }
}
```

## Debug Output Example

When debug mode is enabled, ARGuestures will print detailed gesture information:

```
😀 ARGesture Debug: [Drag] Entity: robot Position: SIMD3<Float>(0.1, 0.5, -0.2) Offset: SIMD3<Float>(0.05, 0.0, -0.1)
😀 ARGesture Debug: [Rotate] Entity: robot Rotation: SIMD3<Float>(0.0, 0.5, 0.0) Angle: 0.5
😀 ARGesture Debug: [Scale] Entity: robot Scale: SIMD3<Float>(1.5, 1.5, 1.5) Scale Factor: 1.5
😀 ARGesture Debug: [Gesture Ended] Entity: robot Final Position: SIMD3<Float>(0.1, 0.5, -0.2) Rotation: SIMD3<Float>(0.0, 0.5, 0.0) Scale: SIMD3<Float>(1.5, 1.5, 1.5)
```

## Examples

Check out our [example project](https://github.com/lazygunner/ARGuesturesDemo) for complete usage.

## License

ARGuestures is released under the MIT license. See [LICENSE](LICENSE) file for details. 