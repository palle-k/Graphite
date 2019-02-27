//
//  ViewController.swift
//  GraphiteDemo
//
//  Created by Palle Klewitz on 18.12.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import UIKit
import Graphite

extension Int {
	static func random(max: Int) -> Int {
		return Int(arc4random_uniform(UInt32(max)))
	}
}

class ViewController: UIViewController {

	var presenter: WeightedGraphPresenter!
	
//	var nodes: [Int: (name: String, color: UIColor)] = [:]
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let nodes = 1...100
//        let edges = nodes.map {
////            Graph.Edge(nodes: [$0, Int(sqrt(Double($0)))], weight: 1)
//            Graph.Edge(nodes: [$0, Int.random(max: $0-1)], weight: 1)
////            Graph.Edge(nodes: [$0, $0 % 2], weight: 1)
//        }
        
        let edges: [Graph.Edge] = (0 ..< 100).map { a in
            let b = max(min(100, Int.random(max: 8) - 4 + a), 0)
            return Graph.Edge(nodes: [a, b], weight: 0.1)
        }
        
		let graph = Graph(nodes: nodes, edges: edges)
		
		presenter = WeightedGraphPresenter(graph: Graph(nodes: [], edges: []), view: self.view)
		presenter.collisionDistance = 0
		presenter.delegate = self
		presenter.edgeColor = UIColor.gray
		presenter.start()
		presenter.graph = graph
        presenter.backgroundColor = .white
	}
}

extension ViewController: WeightedGraphPresenterDelegate {
	func view(for node: Int, presenter: WeightedGraphPresenter) -> UIView {
		let view = UIView()
		view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
		view.layer.cornerRadius = 10
		view.layer.backgroundColor = UIColor(hue: CGFloat(node) / 100, saturation: 1, brightness: 1, alpha: 1).cgColor
		return view
	}
	
	func configure(view: UIView, for node: Int, presenter: WeightedGraphPresenter) {
		
	}
	
	func visibleRange(for node: Int, presenter: WeightedGraphPresenter) -> ClosedRange<Float>? {
		return nil
	}
}
