//
//  WeightedGraphInteractor.swift
//  Graphite
//
//  Created by Palle Klewitz on 19.12.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import UIKit

class WeightedGraphInteractor {
	var nodeViews: [Int: UIView] = [:]
	private var viewIDs: [UIView: Int] {
		return Dictionary(nodeViews.map {($1, $0)}, uniquingKeysWith: {a, _ in a})
	}
	
	private let view: GraphWeightView
	private let animator: UIWeightedGraphAnimator
	
	private var knownTouches: Set<UITouch> = []
	private var pannedViews: [UITouch: UIView] = [:]
	private var velocityTracker = TouchVelocityTracker()
	
	var onPinch: (() -> ())?
	
	init(view: GraphWeightView, animator: UIWeightedGraphAnimator) {
		self.view = view
		self.animator = animator
		
		let panRecognizer = UIMultiPanGestureRecognizer(target: self, action: #selector(self.didPan(_:)))
		view.addGestureRecognizer(panRecognizer)
		
		let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.didPinch(_:)))
		view.addGestureRecognizer(pinchRecognizer)
		
		view.onTouchesBegan = {
			self.animator.setCenter(animator.center, inerialVelocity: .zero)
		}
	}
	
	@objc func didPan(_ recognizer: UIMultiPanGestureRecognizer) {
		func updateContainer(newTouches: Set<UITouch>, movedTouches: Set<UITouch>, endedTouches: Set<UITouch>) {
			let newViews = newTouches.flatMap { touch -> (UITouch, UIView)? in
				let location = touch.location(in: self.view)
				guard let view = self
					.view
					.subviews
					.lazy
					.reversed()
					.filter({!$0.isHidden})
					.first(where: {$0.frame.extended(by: 8).contains(location)})
					else {
						return nil
				}
				return (touch, view)
			}
			
			newTouches.forEach(velocityTracker.update)
			movedTouches.forEach(velocityTracker.update)
			endedTouches.forEach(velocityTracker.update)
			
			UIView.animate(withDuration: 0.2) {
				newViews.map{$1}.forEach { view in
					view.transform = view.transform.concatenating(CGAffineTransform(scaleX: 1.3, y: 1.3))
				}
				endedTouches.flatMap {self.pannedViews[$0]}.forEach { view in
					view.transform = view.transform.concatenating(CGAffineTransform(scaleX: 1.3, y: 1.3).inverted())
				}
			}
			
			endedTouches.forEach { touch in
				guard let view = pannedViews[touch], let id = viewIDs[view] else {
					return
				}
				let velocity = self.velocityTracker.velocity(for: touch)
				self.animator.endUserInteraction(on: id, with: velocity)
			}
			
			newViews.flatMap {viewIDs[$0.1]}.forEach { id in
				self.animator.beginUserInteraction(on: id)
			}
			pannedViews.merge(newViews, uniquingKeysWith: {a, _ in a})
			
			movedTouches.forEach { touch in
				guard let view = pannedViews[touch], let id = viewIDs[view] else {
					return
				}
				let location = touch.location(in: self.view)
				self.animator.moveItem(for: id, to: location)
			}
			
			let nonNodeMovedTouches = movedTouches.filter { touch in
				self.pannedViews[touch].flatMap {self.viewIDs[$0]} == nil
			}
			
			let globalMovement = nonNodeMovedTouches.reduce(CGVector.zero) { vector, touch in
				let previousLocation = touch.previousLocation(in: self.view)
				let location = touch.location(in: self.view)
				
				let dx = location.x - previousLocation.x
				let dy = location.y - previousLocation.y
				
				return CGVector(dx: dx, dy: dy) + vector
			}
			
			let nonNodeEndedTouches = endedTouches.filter { touch in
				self.pannedViews[touch].flatMap {self.viewIDs[$0]} == nil
			}
			
			if nonNodeMovedTouches.isEmpty && !nonNodeEndedTouches.isEmpty {
				let globalVelocity: CGVector = nonNodeEndedTouches.map(velocityTracker.velocity).reduce(.zero) { velocity, touchVelocity in
					return velocity + touchVelocity
				}
				animator.setCenter(
					animator.center + globalMovement * (1 / CGFloat(max(1, nonNodeMovedTouches.count))),
					inerialVelocity: globalVelocity
				)
			} else {
				animator.setCenter(animator.center + globalMovement * (1 / CGFloat(max(1, nonNodeMovedTouches.count))))
			}
			
			endedTouches.forEach { touch in
				self.pannedViews.removeValue(forKey: touch)
			}
			
			knownTouches.subtract(endedTouches)
			knownTouches.formUnion(newTouches)
			
			endedTouches.forEach(velocityTracker.endTracking)
		}
		
		switch recognizer.state {
		case .began:
			updateContainer(newTouches: recognizer.activeTouches, movedTouches: [], endedTouches: knownTouches)
			
		case .changed:
			let newTouches = recognizer.activeTouches.subtracting(knownTouches)
			let movedTouches = recognizer.activeTouches.intersection(knownTouches)
			let endedTouches = knownTouches.subtracting(recognizer.activeTouches)
			
			updateContainer(newTouches: newTouches, movedTouches: movedTouches, endedTouches: endedTouches)
			
		default:
			updateContainer(newTouches: [], movedTouches: [], endedTouches: knownTouches)
			knownTouches.removeAll()
			pannedViews.removeAll()
		}
	}
	
	private var startRadius: CGFloat?
	
	@objc func didPinch(_ recognizer: UIPinchGestureRecognizer) {
		switch recognizer.state {
		case .began:
			startRadius = animator.radius
			
		case .changed:
			if let startRadius = self.startRadius {
				animator.radius = startRadius * recognizer.scale
			}
			break
			
		case .ended:
			if let startRadius = self.startRadius {
				animator.radius = startRadius * recognizer.scale
			}
			startRadius = nil
			
		default:
			break
		}
		
		onPinch?()
	}
}
