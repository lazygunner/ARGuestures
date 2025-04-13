import Foundation
import RealityKit
import SwiftUI
import Combine

/// AR手势类型枚举
public enum ARGestureType {
    /// 拖拽手势
    case drag
    /// 旋转手势
    case rotate
    /// 缩放手势
    case scale
    /// 手势结束
    case gestureEnded
}

/// 手势回调信息结构
public struct ARGestureInfo {
    /// 手势类型
    public let gestureType: ARGestureType
    /// 实体名称
    public let entityName: String
    /// 变换信息
    public let transform: Transform
    /// 初始变换（开始时）
    public let initialTransform: Transform?
    /// 变化值（如缩放系数，旋转角度等）
    public let changeValue: Any?
    
    /// 初始化手势信息
    public init(
        gestureType: ARGestureType,
        entityName: String,
        transform: Transform,
        initialTransform: Transform? = nil,
        changeValue: Any? = nil
    ) {
        self.gestureType = gestureType
        self.entityName = entityName
        self.transform = transform
        self.initialTransform = initialTransform
        self.changeValue = changeValue
    }
}

/// 手势回调类型
public typealias ARGestureCallback = (ARGestureInfo) -> Void

/// 位置变化回调类型
public typealias TransformChangedCallback = (String, Transform) -> Void

/// AR手势管理器，负责管理实体和手势交互
public class ARGestureManager: ObservableObject {
    /// 活跃的实体列表
    @Published public var entities: [EntityData] = []
    
    /// 是否可以放置对象
    @Published public var placeAble: Bool = false
    
    /// 放置位置
    @Published public var placementPosition: SIMD3<Float>?
    
    /// 调试模式开关
    @Published public var isDebugEnabled: Bool = false
    
    /// 实体映射表，用于快速查找
    private var entityMap: [String: EntityData] = [:]
    
    /// 实体组件映射，用于快速查找手势交互的实体
    private var entityComponentMap: [Entity: String] = [:]
    
    /// 平面锚点映射
    public var planeAnchorsByID: [UUID: ARMeshAnchor] = [:]
    
    /// 平面实体映射
    public var planeEntities: [UUID: Entity] = [:]
    
    /// 参考锚点实体
    public var referenceAnchor: Entity?
    
    /// 放置指示实体
    public var placementInstructionEntity: Entity?
    
    /// 变换回调
    public var onTransformChanged: TransformChangedCallback?
    
    /// 手势回调
    public var onGestureCallback: ARGestureCallback?
    
    /// 初始化AR手势管理器
    /// - Parameters:
    ///   - referenceAnchor: 可选参考锚点
    ///   - placementInstructionEntity: 可选放置指示实体
    ///   - isDebugEnabled: 是否启用调试模式，默认为false
    public init(
        referenceAnchor: Entity? = nil, 
        placementInstructionEntity: Entity? = nil,
        isDebugEnabled: Bool = false
    ) {
        self.referenceAnchor = referenceAnchor
        self.placementInstructionEntity = placementInstructionEntity
        self.isDebugEnabled = isDebugEnabled
    }
    
    /// 添加实体到管理器
    /// - Parameters:
    ///   - entity: 要添加的实体
    ///   - name: 实体名称
    /// - Returns: 添加的实体数据
    @discardableResult
    public func addEntity(_ entity: Entity, name: String) -> EntityData {
        let entityData = EntityData(entity: entity, name: name)
        entityMap[name] = entityData
        entities.append(entityData)
        
        // 注册实体及其子级以便快速查找
        registerEntityHierarchy(entity, name: name)
        
        return entityData
    }
    
    /// 注册实体层级结构，用于快速查找
    /// - Parameters:
    ///   - entity: 要注册的实体
    ///   - name: 实体名称
    private func registerEntityHierarchy(_ entity: Entity, name: String) {
        // 首先为主实体创建映射
        entityComponentMap[entity] = name
        
        // 注册子实体
        if !entity.children.isEmpty {
            registerChildren(of: entity, name: name)
        }
    }
    
    /// 递归注册子实体
    /// - Parameters:
    ///   - entity: 父实体
    ///   - name: 主实体名称
    private func registerChildren(of entity: Entity, name: String) {
        for child in entity.children {
            entityComponentMap[child] = name
            
            // 递归处理孙子级
            if !child.children.isEmpty {
                registerChildren(of: child, name: name)
            }
        }
    }
    
    /// 根据交互实体查找主实体
    /// - Parameter interactedEntity: 被交互的实体
    /// - Returns: 找到的实体数据和名称
    public func findEntityData(from interactedEntity: Entity) -> (EntityData?, String) {
        // 首先尝试直接在映射表中查找
        if let entityName = entityComponentMap[interactedEntity] {
            return (entityMap[entityName], entityName)
        }
        
        // 尝试查找父级
        var currentEntity: Entity? = interactedEntity
        while currentEntity != nil {
            if let name = entityComponentMap[currentEntity!] {
                return (entityMap[name], name)
            }
            currentEntity = currentEntity?.parent
        }
        
        // 如果都找不到，使用旧方法作为后备
        for entData in entities {
            let ent = entData.entity
            let name = entData.name
            
            // 检查是否是主实体
            if ent == interactedEntity {
                return (entData, name)
            }
            
            // 检查是否是子实体
            if isEntity(interactedEntity, childOf: ent) {
                return (entData, name)
            }
        }
        
        return (nil, "")
    }
    
    /// 检查一个实体是否是另一个实体的子级
    /// - Parameters:
    ///   - potentialChild: 可能的子实体
    ///   - parent: 可能的父实体
    /// - Returns: 是否是子级关系
    private func isEntity(_ potentialChild: Entity, childOf parent: Entity) -> Bool {
        if parent.children.contains(potentialChild) {
            return true
        }
        
        for child in parent.children {
            if isEntity(potentialChild, childOf: child) {
                return true
            }
        }
        
        return false
    }
    
    /// 移除实体
    /// - Parameter name: 实体名称
    public func removeEntity(named name: String) {
        if let entityData = entityMap[name] {
            // 从实体组件映射中移除
            removeEntityFromComponentMap(entityData.entity)
            
            // 从实体列表中移除
            if let index = entities.firstIndex(where: { $0.name == name }) {
                entities.remove(at: index)
                entityMap.removeValue(forKey: name)
            }
        }
    }
    
    /// 从组件映射中移除实体及其子实体
    /// - Parameter entity: 要移除的实体
    private func removeEntityFromComponentMap(_ entity: Entity) {
        entityComponentMap.removeValue(forKey: entity)
        
        // 递归移除所有子实体
        for child in entity.children {
            removeEntityFromComponentMap(child)
        }
    }
    
    /// 获取实体
    /// - Parameter name: 实体名称
    /// - Returns: 实体数据（如果存在）
    public func getEntity(named name: String) -> EntityData? {
        return entityMap[name]
    }
    
    /// 放置对象在指定位置
    /// - Parameter entity: 要放置的实体
    public func placeObject(_ entity: Entity) {
        if let position = placementPosition {
            entity.setPosition(position, relativeTo: nil)
        }
    }
    
    /// 发送变换消息
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - transform: 变换信息
    public func notifyTransformChanged(_ entityName: String, _ transform: Transform) {
        onTransformChanged?(entityName, transform)
    }
    
    /// 设置变换回调
    /// - Parameter callback: 回调函数
    public func setTransformChangedCallback(_ callback: @escaping TransformChangedCallback) {
        self.onTransformChanged = callback
    }
    
    /// 获取相对变换
    /// - Parameter transform: 原始变换
    /// - Returns: 相对于参考锚点的变换
    public func getRelativeTransform(_ transform: Transform) -> Transform {
        guard let anchor = referenceAnchor else { return transform }
        return anchor.convert(transform: transform, from: nil)
    }
    
    /// 设置手势回调
    /// - Parameter callback: 手势回调函数
    public func setGestureCallback(_ callback: @escaping ARGestureCallback) {
        self.onGestureCallback = callback
    }
    
    /// 通知手势事件
    /// - Parameter gestureInfo: 手势信息
    public func notifyGestureEvent(_ gestureInfo: ARGestureInfo) {
        onGestureCallback?(gestureInfo)
        
        if isDebugEnabled {
            let changeValueStr = gestureInfoString(gestureInfo)
            print("😀 ARGesture 调试: [\(gestureTypeString(gestureInfo.gestureType))] 实体: \(gestureInfo.entityName) \(changeValueStr)")
        }
    }
    
    /// 获取手势类型的字符串表示
    private func gestureTypeString(_ type: ARGestureType) -> String {
        switch type {
        case .drag:
            return "拖拽"
        case .rotate:
            return "旋转"
        case .scale:
            return "缩放"
        case .gestureEnded:
            return "手势结束"
        }
    }
    
    /// 获取手势信息的字符串表示
    private func gestureInfoString(_ info: ARGestureInfo) -> String {
        var result = ""
        
        switch info.gestureType {
        case .drag:
            result += "位置: \(info.transform.translation)"
            if let initialTransform = info.initialTransform {
                let offset = info.transform.translation - initialTransform.translation
                result += " 偏移: \(offset)"
            }
        case .rotate:
            result += "旋转: \(info.transform.rotation.convertToEulerAngles())"
            if let angle = info.changeValue as? Float {
                result += " 角度: \(angle)"
            }
        case .scale:
            result += "缩放: \(info.transform.scale)"
            if let magnification = info.changeValue as? Float {
                result += " 缩放系数: \(magnification)"
            }
        case .gestureEnded:
            result += "最终位置: \(info.transform.translation) 旋转: \(info.transform.rotation.convertToEulerAngles()) 缩放: \(info.transform.scale)"
        }
        
        return result
    }
    
    /// 启用或禁用调试模式
    /// - Parameter enabled: 是否启用调试
    public func setDebugEnabled(_ enabled: Bool) {
        self.isDebugEnabled = enabled
    }
}

/// 平面检测辅助函数
public func containing(pointToProject: float4x4, _ anchor: ARMeshAnchor) -> Bool {
    let anchorTLocalPoint = anchor.transformMatrix.inverse * pointToProject
    let x = anchorTLocalPoint.columns.3.x
    let z = anchorTLocalPoint.columns.3.z
    let extent = anchor.geometry.extent
    
    // 中心点在原点，边界判断
    return -extent.x / 2 <= x && x <= extent.x / 2 && -extent.z / 2 <= z && z <= extent.z / 2
} 