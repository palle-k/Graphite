//
//  WeightedGraphSimulator.swift
//  Graphite
//
//  Created by Palle Klewitz on 18.12.17.
//  Copyright (c) 2017 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import UIKit
import Accelerate
import SceneKit
import ARKit

open class WeightedGraphSimulator {
	open var graph: Graph {
		didSet {
			weights = [:]
			for relation in graph.edges {
				for (a, b) in relation.nodes.cross(relation.nodes) {
					weights[a, default: [:]][b] = relation.weight
				}
			}
			
			for node in graph.nodes where !nodes.keys.contains(node) {
				let position = UnsafeMutablePointer<Float>.allocate(capacity: dimensions)
				position.assign(from: self.position(for: node), count: dimensions)
				let velocity = UnsafeMutablePointer<Float>.allocate(capacity: dimensions)
				velocity.assign(from: Array<Float>(repeating: 0, count: dimensions), count: dimensions)
				
				nodes[node] = (position, velocity)
			}
			
			for node in nodes.keys where !graph.nodes.contains(node) {
				if let (position, velocity) = nodes[node] {
					position.deallocate(capacity: dimensions)
					velocity.deallocate(capacity: dimensions)
				}
				nodes[node] = nil
			}
		}
	}
	
	deinit {
		nodes.values.forEach { position, velocity in
			position.deallocate(capacity: dimensions)
			velocity.deallocate(capacity: dimensions)
		}
	}
	
	private var weights: [Int: [Int: Float]] = [:]
	
	private var nodes: [Int: (position: UnsafeMutablePointer<Float>, velocity: UnsafeMutablePointer<Float>)] = [:]
	public var nodePositions: [Int: UnsafePointer<Float>] {
		return nodes.mapValues { position, _ in
			UnsafePointer(position)
		}
	}
	
	open var damping: Float = 2
	public let dimensions: Int
	open var radius: Float = 2
	open var collisionRadius: Float = 0.5
	
	public private(set) var interactedNodes: Set<Int> = []
	public private(set) var passiveNodes: Set<Int> = []
	
	open var center: [Float] {
		didSet {
			assert(center.count == dimensions, "Number of dimensions and dimensionality of center point must match.")
		}
	}
	open var centerVelocity: [Float] {
		didSet {
			assert(centerVelocity.count == dimensions, "Number of dimensions and dimensionality of center velocity must match.")
		}
	}
	
	public init(dimensions: Int, graph: Graph, center: [Float]) {
		precondition(dimensions == center.count, "Number of dimensions and dimensionality of center point must match.")
		
		self.dimensions = dimensions
		self.center = center
		self.centerVelocity = Array(repeating: 0, count: dimensions)
		self.graph = graph
	}
	
	open func update(interval: TimeInterval) {
		// Updates only velocities
		updateRelationalVelocities(interval: interval)
		removeGlobalDrift(interval: interval)
		
		// Write new positions
		applyVelocities(interval: interval)
		recenterGraph(interval: interval)
	}
	
	@inline(__always)
	private final func updateRelationalVelocities(interval: TimeInterval) {
		let direction = UnsafeMutablePointer<Float>.allocate(capacity: dimensions)
		defer {
			direction.deallocate(capacity: dimensions)
		}
		
		for (key: node, value: (position: position, velocity: velocity)) in nodes where !interactedNodes.contains(node) {
			
			let nodeWeights = weights[node] ?? [:]
			
			for (key: otherNode, value: (position: otherPosition, velocity: _)) in nodes where otherNode != node && !passiveNodes.contains(otherNode) {
				let weight = nodeWeights[otherNode] ?? 0
				
				self.directionVector(from: position, to: otherPosition, result: direction)
				
				// Calculating distance between the nodes
				var distanceSquared: Float = 0
				vDSP_distancesq(position, 1, otherPosition, 1, &distanceSquared, UInt(dimensions))
				let distance = sqrt(distanceSquared)
				
				let strength: Float = weight * 0.3 + 0.2
				let expectedDistance: Float = radius
				
				let acceleration: Float
				
				if distance < collisionRadius {
					acceleration = (-1 / pow(distance, 2) + 1 / pow(collisionRadius, 2)) * 10
				} else if weight == 0 {
					acceleration = -1 / distanceSquared * radius
				} else {
					acceleration = (distance - expectedDistance) / distance * strength * 20
				}
				
				// Apply acceleration to velocity
				vDSP_vsma(direction, 1, [acceleration * Float(interval)], velocity, 1, velocity, 1, UInt(dimensions))
			}
			
			// Applying acceleration towards center point
			self.addCenterAcceleration(from: position, with: 10 * Float(interval) / radius, to: velocity, buffer: direction)
			
			// Apply velocity damping
			vDSP_vsmul(velocity, 1, [1 - damping * Float(interval)], velocity, 1, UInt(dimensions))
		}
	}
	
	@inline(__always)
	private final func removeGlobalDrift(interval: TimeInterval) {
		var driftVelocity = nodes.reduce(into: [Float](repeating: 0, count: dimensions)) { (result: inout ([Float]), element) in
			vDSP_vadd(result, 1, element.value.velocity, 1, &result, 1, UInt(dimensions))
		}
		vDSP_vsdiv(driftVelocity, 1, [Float(max(1, nodes.count))], &driftVelocity, 1, UInt(dimensions))
		
		for (key: node, value: (position: _, velocity: velocity)) in nodes where !interactedNodes.contains(node) {
			vDSP_vsub(driftVelocity, 1, velocity, 1, velocity, 1, UInt(dimensions))
		}
	}
	
	@inline(__always)
	private final func applyVelocities(interval: TimeInterval) {
		for (key: node, value: (position: position, velocity: velocity)) in nodes where !interactedNodes.contains(node) {
			vDSP_vsma(velocity, 1, [Float(interval)], position, 1, position, 1, UInt(dimensions))
		}
	}
	
	@inline(__always)
	private func recenterGraph(interval: TimeInterval) {
		let centerDirection = UnsafeMutablePointer<Float>.allocate(capacity: dimensions)
		defer {
			centerDirection.deallocate(capacity: dimensions)
		}
		
		vDSP_vsma(centerVelocity, 1, [Float(interval)], center, 1, &center, 1, UInt(dimensions))
		vDSP_vsmul(centerVelocity, 1, [1 - damping * Float(interval)], &centerVelocity, 1, UInt(dimensions))
//		vDSP_vsadd(centerDirection, 1, [-damping * Float(interval)], &centerVelocity, 1, UInt(dimensions))
//		vDSP_vclip(centerDirection, 1, [0], [1], &centerVelocity, 1, UInt(dimensions))
		
		var nodeCenter = nodes.reduce(into: [Float](repeating: 0, count: dimensions)) { (result: inout ([Float]), element) in
			vDSP_vadd(result, 1, element.value.position, 1, &result, 1, UInt(self.dimensions))
		}
		vDSP_vsdiv(nodeCenter, 1, [Float(max(1, nodes.count))], &nodeCenter, 1, UInt(dimensions))
		directionVector(from: nodeCenter, to: self.center, result: centerDirection)
		
		for (key: node, value: (position: position, velocity: _)) in nodes where !interactedNodes.contains(node) {
			vDSP_vadd(position, 1, centerDirection, 1, position, 1, UInt(dimensions))
		}
	}
	
	func position(for tag: Int) -> [Float] {
		if dimensions == 2 {
			let angle = Float(drand48()) * 2 * .pi
			return [
				cos(angle) * radius * sqrt(Float(nodes.count)) + center[0],
				sin(angle) * radius * sqrt(Float(nodes.count)) + center[1]
			]
		} else {
			return (0..<dimensions).map({_ in Float(drand48())})
		}
	}
	
	@inline(__always)
	private final func directionVector(from p1: UnsafePointer<Float>, to p2: UnsafePointer<Float>, result: UnsafeMutablePointer<Float>) {
		vDSP_vsub(p1, 1, p2, 1, result, 1, UInt(dimensions))
	}
	
	@inline(__always)
	private final func normalize(_ vector: [Float]) -> [Float] {
		var distanceSquared: Float = 0
		vDSP_svesq(vector, 1, &distanceSquared, UInt(dimensions))
		var result = vector
		vDSP_vsdiv(vector, 1, [sqrt(distanceSquared)], &result, 1, UInt(dimensions))
		return result
	}
	
	@inline(__always)
	private final func addCenterAcceleration(from point: UnsafePointer<Float>, with factor: Float, to result: UnsafeMutablePointer<Float>, buffer: UnsafeMutablePointer<Float>) {
		let dir = buffer
		directionVector(from: point, to: center, result: dir)
		var distanceSquared: Float = 0
		vDSP_distancesq(point, 1, center, 1, &distanceSquared, UInt(dimensions))
		let distance = sqrt(distanceSquared)
		vDSP_vsma(dir, 1, [1 / (distance + 1) * factor], result, 1, result, 1, UInt(dimensions))
	}
	
	public func set(location: [Float], for key: Int) {
		guard let (l, _) = nodes[key] else {
			return
		}
		l.assign(from: location, count: dimensions)
	}
	
	public func beginUserInteraction(on node: Int) {
		interactedNodes.insert(node)
	}
	
	public func endUserInteraction(on node: Int) {
		interactedNodes.remove(node)
	}
	
	public func endUserInteraction(on node: Int, with velocity: [Float]) {
		interactedNodes.remove(node)
		guard let (_, v) = nodes[node] else {
			return
		}
		v.assign(from: velocity, count: dimensions)
	}
	
	public func disableForce(from node: Int) {
		passiveNodes.insert(node)
	}
	
	public func enableForce(from node: Int) {
		passiveNodes.remove(node)
	}
}
