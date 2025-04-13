# ARGuestures

ARGuestures 是一个为 VisionOS 应用程序中的 Entity 提供 AR 交互手势能力的 Swift 包。

## 功能

- 拖拽：移动 3D 物体
- 旋转：旋转 3D 物体（支持自定义旋转轴）
- 缩放：调整 3D 物体大小
- 平面检测：支持将物体放置在检测到的平面上
- 手势回调：监听手势事件并获取变化值
- 调试模式：打印详细的手势信息
- 高效实体查找：使用映射表快速定位手势交互的实体
- 可定制旋转：指定旋转轴或禁用旋转

## 要求

- visionOS 1.0+
- Swift 6.0+
- Xcode 15.0+

## 安装

### Swift Package Manager

在 `Package.swift` 文件中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/layzgunner/ARGuestures.git", from: "1.0.0")
]
```

## 使用方法

### 初始化 ARGestureManager

```swift
import ARGuestures
import RealityKit
import SwiftUI

// 创建锚点和提示实体
let referenceAnchor = Entity()
let placementInstructionEntity = Entity()

// 初始化手势管理器（开启调试模式）
let gestureManager = ARGuestures.createManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity,
    isDebugEnabled: true  // 启用调试输出
)

// 或者直接初始化
let manager = ARGestureManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity
)

// 添加 3D 模型实体
let modelEntity = try! await Entity.load(named: "toy_robot")
gestureManager.addEntity(modelEntity, name: "robot")

// 设置变换回调
gestureManager.setTransformChangedCallback { (entityName, transform) in
    print("实体 \(entityName) 变换为: \(transform)")
}

// 设置手势回调（监控所有手势事件）
gestureManager.setGestureCallback { gestureInfo in
    switch gestureInfo.gestureType {
    case .drag:
        print("正在拖拽: \(gestureInfo.entityName)")
    case .rotate:
        print("正在旋转: \(gestureInfo.entityName)")
    case .scale:
        if let magnification = gestureInfo.changeValue as? Float {
            print("正在缩放: \(gestureInfo.entityName), 缩放系数: \(magnification)")
        }
    case .gestureEnded:
        print("手势结束: \(gestureInfo.entityName)")
    }
}
```

### 启用或禁用调试模式

```swift
// 启用调试模式
gestureManager.setDebugEnabled(true)

// 禁用调试模式
gestureManager.setDebugEnabled(false)

// 直接设置
gestureManager.isDebugEnabled = true
```

### 为视图添加手势支持

```swift
import ARGuestures
import RealityKit
import SwiftUI

struct ContentView: View {
    @StateObject var gestureManager: ARGestureManager
    
    var body: some View {
        RealityView { content in
            // 设置场景内容
            if let anchor = gestureManager.referenceAnchor {
                content.add(anchor)
            }
            
            // 添加模型
            if let entity = gestureManager.entities.first?.entity {
                content.add(entity)
            }
            
            // 添加放置指示
            if let placementEntity = gestureManager.placementInstructionEntity {
                content.add(placementEntity)
            }
        }
        // 默认设置（Y轴旋转）
        .withARGestures(manager: gestureManager)
        
        // 或指定旋转轴
        .withARGestures(
            manager: gestureManager,
            rotationAxis: .x  // 绕X轴旋转
        )
        
        // 或完全禁用旋转
        .withARGestures(
            manager: gestureManager,
            rotationEnabled: false
        )
        
        // 或使用便捷方法仅启用拖拽和缩放
        .withARDragAndScaleGestures(manager: gestureManager)
    }
}
```

### 单独使用各种手势

如果只需要特定的手势功能，可以单独使用：

```swift
// 仅使用拖拽和旋转手势（Y轴旋转）
myView.onDragAndRotate(manager: gestureManager)

// 指定旋转轴
myView.onDragAndRotate(
    manager: gestureManager,
    rotationAxis: .z  // 绕Z轴旋转
)

// 仅使用拖拽手势（无旋转）
myView.onDragOnly(manager: gestureManager)

// 仅使用缩放手势
myView.onScale(manager: gestureManager)
```

## 管理实体

ARGestureManager 提供了多种方法来管理实体：

```swift
// 添加实体
let entityData = gestureManager.addEntity(newEntity, name: "新实体")

// 获取实体
if let entity = gestureManager.getEntity(named: "robot") {
    // 使用找到的实体...
}

// 移除实体
gestureManager.removeEntity(named: "robot")

// 根据交互的实体查找主实体
let (entityData, entityName) = gestureManager.findEntityData(from: interactedEntity)
```

## 高效实体查找

ARGuestures 使用多层缓存机制提供高效的实体查找：

1. **实体映射表**: 所有注册的实体都存储在O(1)时间复杂度的哈希表中
2. **组件映射**: 为实体和所有子实体创建映射关系，支持快速查找
3. **层级遍历**: 对于复杂结构，可以沿着父级链向上查找
4. **后备系统**: 对于特殊情况，提供完整的递归搜索作为后备方案

这种多层查找机制确保手势交互拥有最佳性能，即使在复杂场景中也能保持流畅的用户体验。

## 手势监控

通过手势回调，您可以监控所有手势事件并获取详细信息：

```swift
gestureManager.setGestureCallback { info in
    // 手势类型
    let gestureType = info.gestureType
    
    // 实体名称
    let entityName = info.entityName
    
    // 当前变换
    let transform = info.transform
    
    // 初始变换（开始时）
    if let initialTransform = info.initialTransform {
        // 计算变化量
        let translationDiff = transform.translation - initialTransform.translation
        print("位置偏移: \(translationDiff)")
    }
    
    // 特定变化值
    if let changeValue = info.changeValue {
        if info.gestureType == .scale {
            // 缩放系数
            let magnification = changeValue as! Float
            print("缩放系数: \(magnification)")
        } else if info.gestureType == .rotate {
            // 旋转角度
            let angle = changeValue as! Float
            print("旋转角度: \(angle)")
        }
    }
}
```

## 调试输出示例

当启用调试模式时，ARGuestures 会打印详细的手势信息：

```
😀 ARGesture 调试: [拖拽] 实体: robot 位置: SIMD3<Float>(0.1, 0.5, -0.2) 偏移: SIMD3<Float>(0.05, 0.0, -0.1)
😀 ARGesture 调试: [旋转] 实体: robot 旋转: SIMD3<Float>(0.0, 0.5, 0.0) 角度: 0.5
😀 ARGesture 调试: [缩放] 实体: robot 缩放: SIMD3<Float>(1.5, 1.5, 1.5) 缩放系数: 1.5
😀 ARGesture 调试: [手势结束] 实体: robot 最终位置: SIMD3<Float>(0.1, 0.5, -0.2) 旋转: SIMD3<Float>(0.0, 0.5, 0.0) 缩放: SIMD3<Float>(1.5, 1.5, 1.5)
```

## 示例

查看我们的 [示例项目](https://github.com/lazygunner/ARGuesturesDemo) 了解完整用法。

## 许可证

ARGuestures 在 MIT 许可下发布。详见 [LICENSE](LICENSE) 文件。 