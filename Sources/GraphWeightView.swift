//
//  GraphWeightView.swift
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

open class GraphWeightView: UIView {
	public var weights: [(UIView, UIView, Double)] = []
	public var strokeColor: UIColor = .white {
		didSet {
			layer.setNeedsDisplay()
		}
	}
	
	var onLayout: (() -> ())? = nil
	
	open override func awakeFromNib() {
		super.awakeFromNib()
		
		self.layer.contentsScale = UIScreen.main.scale
		self.layer.drawsAsynchronously = true
		self.layer.setNeedsDisplay()
	}
	
	open override func draw(_ layer: CALayer, in ctx: CGContext) {
		guard layer == self.layer else {
			return
		}
		
		ctx.clear(self.bounds)
		ctx.setStrokeColor(strokeColor.cgColor)
		
		for (v1, v2, weight) in weights {
			ctx.move(to: v1.center)
			ctx.addLine(to: v2.center)
			ctx.setLineWidth(CGFloat(weight) * 3 + 2)
			ctx.setAlpha(CGFloat(weight) * 0.5 + 0.5)
			ctx.strokePath()
		}
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()
		onLayout?()
	}
}
