//
//  Utility.swift
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
import Accelerate

extension Sequence {
	func pick(_ n: Int) -> [Element] {
		let arr = Array(self)
		let indices = (0 ..< n).reduce([]) { (indices, _) -> [Int] in
			let rnd = Int(arc4random_uniform(UInt32(arr.count - indices.count)))
			let index = indices.reduce(rnd) { newIndex, existingIndex in
				newIndex + (newIndex >= existingIndex ? 1 : 0)
			}
			return (indices + [index]).sorted()
		}
		return indices.map{arr[$0]}
	}
	
	func cross<Other: Sequence>(_ other: Other) -> [(Element, Other.Element)] {
		return self.flatMap { element -> [(Element, Other.Element)] in
			other.map { otherElement in
				(element, otherElement)
			}
		}
	}
}

extension CGRect {
	func extended(by length: CGFloat) -> CGRect {
		return CGRect(x: minX - length, y: minY - length, width: width + 2 * length, height: height + 2 * length)
	}
}
