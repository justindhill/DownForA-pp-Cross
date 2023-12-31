//
//  PuzzleView.swift
//  DownForACross
//
//  Created by Justin Hill on 12/18/23.
//

import UIKit

protocol PuzzleViewDelegate: AnyObject {
    func puzzleView(_ puzzleView: PuzzleView, didEnterText text: String?, atCoordinates coordinates: CellCoordinates)
    func puzzleView(_ puzzleView: PuzzleView, userCursorDidMoveToCoordinates coordinates: CellCoordinates)
}

class PuzzleView: UIView {

    typealias UserCursor = (coordinates: CellCoordinates, direction: Direction)
    
    enum Direction {
        case across
        case down
        
        var opposite: Direction {
            switch self {
                case .across: return .down
                case .down: return .across
            }
        }
    }
    
    weak var delegate: PuzzleViewDelegate?
    
    var puzzleGrid: [[String?]]
    var solution: [[CellEntry?]] {
        didSet { self.setNeedsLayout() }
    }
    
    var cursors: [String: CellCoordinates] {
        didSet { self.setNeedsLayout() }
    }
    
    var userCursor: UserCursor = (CellCoordinates(row: 0, cell: 0), .down) {
        didSet {
            if oldValue.coordinates != userCursor.coordinates {
                self.delegate?.puzzleView(self, userCursorDidMoveToCoordinates: userCursor.coordinates)
            }
            
            self.setNeedsLayout()
        }
    }
    
    lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizerTriggered))
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    var userCursorIndicatorLayer: CALayer = CALayer()
    var cursorIndicatorLayers: [CALayer] = []
    var numberTextLayers: [CATextLayer] = []
    var fillTextLayers: [CATextLayer] = []
    var separatorLayers: [CALayer] = []
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    var puzzleContainerView: UIView = UIView()
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func didMoveToWindow() {
        if let window = self.window {
            let scale = window.screen.scale
            self.fillTextLayers.forEach({ $0.contentsScale = scale })
        }
    }
    
    init(puzzleGrid: [[String?]]) {
        self.puzzleGrid = puzzleGrid
        self.solution = Array(repeating: Array(repeating: nil,
                                               count: puzzleGrid[0].count),
                              count: puzzleGrid.count)
        self.cursors = [:]
        super.init(frame: .zero)
        
        self.puzzleContainerView.layer.borderWidth = 0.5
        self.puzzleContainerView.layer.borderColor = UIColor.systemGray2.cgColor
        
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.puzzleContainerView)
        self.scrollView.addGestureRecognizer(self.tapGestureRecognizer)
    }
    
    var cellCount: Int {
        guard self.puzzleGrid.count > 0 && self.puzzleGrid[0].count > 0 else { return 0}
        return self.puzzleGrid.count * self.puzzleGrid[0].count
    }
    
    var cellSideLength: CGFloat {
        guard self.cellCount > 0 else { return 0 }
        return self.frame.size.width / CGFloat(self.puzzleGrid[0].count)
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.cellSideLength * CGFloat(self.puzzleGrid.count))
    }
    
    override func layoutSubviews() {
        guard self.puzzleGrid.count > 0 && self.puzzleGrid[0].count > 0 else { return }
        
        self.scrollView.frame = self.bounds
        self.puzzleContainerView.frame = self.bounds
        
        let cellCount = self.cellCount
        let cellSideLength = self.cellSideLength
        
        let sizingFont = UIFont.systemFont(ofSize: 12)
        let pointToCapHeight = sizingFont.pointSize / sizingFont.capHeight
        let baseFillFont = UIFont.systemFont(ofSize: ceil((cellSideLength * 0.4) * pointToCapHeight))
        let numberFont = UIFont.systemFont(ofSize: ceil(baseFillFont.pointSize / 2.8))
        let numberPadding: CGFloat = cellSideLength / 20
        
        let separatorCount = 2 * self.puzzleGrid.count - 2
        self.updateTextLayerCount(target: cellCount, font: baseFillFont)
        self.updateSeparatorCount(target: separatorCount)
        
        var textLayerIndex = 0
        var cellNumber = 1
        for (rowIndex, row) in self.puzzleGrid.enumerated() {
            for (itemIndex, item) in row.enumerated() {
                let layer = self.fillTextLayers[textLayerIndex]
                
                if self.itemRequiresNumberLabel(item, atRow: rowIndex, index: itemIndex) {
                    let numberTextLayer: CATextLayer
                    if cellNumber < self.numberTextLayers.count {
                        numberTextLayer = self.numberTextLayers[cellNumber - 1]
                    } else {
                        numberTextLayer = self.createNumberTextLayer()
                    }
                    numberTextLayer.font = numberFont
                    numberTextLayer.fontSize = numberFont.pointSize
                    numberTextLayer.string = "\(cellNumber)"
                    numberTextLayer.frame = CGRect(x: CGFloat(itemIndex) * cellSideLength + numberPadding,
                                                   y: CGFloat(rowIndex) * cellSideLength + numberPadding,
                                                   width: cellSideLength,
                                                   height: numberFont.lineHeight)
                    cellNumber += 1
                }
                
                if let item {
                    if item == "." {
                        layer.backgroundColor = UIColor.black.cgColor
                        layer.string = nil
                        layer.frame = CGRect(x: CGFloat(itemIndex) * cellSideLength,
                                             y: CGFloat(rowIndex) * cellSideLength,
                                             width: cellSideLength,
                                             height: cellSideLength)
                    } else {
                        let fillFont: UIFont
                        if item.count > 1 {
                            let scaleFactor = pow(CGFloat(0.86), CGFloat(item.count))
                            fillFont = baseFillFont.withSize(baseFillFont.pointSize * scaleFactor)
                        } else {
                            fillFont = baseFillFont
                        }
                        
                        layer.font = fillFont
                        layer.fontSize = fillFont.pointSize
                        
                        let ascenderAdjustment = (fillFont.lineHeight - fillFont.capHeight + fillFont.descender - fillFont.leading)
                        let yCenterOffset = (cellSideLength - fillFont.capHeight) / 2
                        layer.frame = CGRect(x: CGFloat(itemIndex) * cellSideLength,
                                             y: CGFloat(rowIndex) * cellSideLength + yCenterOffset - ascenderAdjustment + 0.5,
                                             width: cellSideLength,
                                             height: fillFont.lineHeight)
                        layer.backgroundColor = UIColor.clear.cgColor
                        
                        if let solutionEntry = self.solution[rowIndex][itemIndex] {
                            layer.string = solutionEntry.value
                        } else {
                            layer.string = nil
                        }
                    }
                } else {
                    layer.backgroundColor = UIColor.clear.cgColor
                    layer.string = nil
                    layer.frame = CGRect(x: CGFloat(itemIndex) * cellSideLength,
                                         y: CGFloat(rowIndex) * cellSideLength,
                                         width: cellSideLength,
                                         height: cellSideLength)
                }
                
                textLayerIndex += 1
            }
        }
        
        // separators
        for i in 0..<self.puzzleGrid.count - 1 {
            let horizontal = self.separatorLayers[i]
            let offset = CGFloat(i + 1) * cellSideLength
            horizontal.frame = CGRect(x: 0, y: offset, width: self.frame.size.width, height: 0.5)
        }
        for i in (self.puzzleGrid.count)..<self.puzzleGrid.count + self.puzzleGrid[0].count - 1 {
            let vertical = self.separatorLayers[i]
            let offset = CGFloat(i - self.puzzleGrid.count + 1) * cellSideLength
            vertical.frame = CGRect(x: offset, y: 0, width: 0.5, height: self.frame.size.height)
        }
        
        // cursors
        self.syncCursorLayerCount()
        for (index, (id, coordinates)) in self.cursors.enumerated() {
            let layer = self.cursorIndicatorLayers[index]
            layer.frame = CGRect(x: CGFloat(coordinates.cell) * cellSideLength,
                                 y: CGFloat(coordinates.row) * cellSideLength,
                                 width: cellSideLength,
                                 height: cellSideLength)
            print(id)
        }
        
        // user cursor
        if self.userCursorIndicatorLayer.superlayer == nil {
            self.puzzleContainerView.layer.addSublayer(self.userCursorIndicatorLayer)
            self.userCursorIndicatorLayer.borderColor = UIColor.systemPink.cgColor
            self.userCursorIndicatorLayer.borderWidth = 2
        }
        self.userCursorIndicatorLayer.frame = CGRect(x: CGFloat(self.userCursor.coordinates.cell) * cellSideLength,
                                                     y: CGFloat(self.userCursor.coordinates.row) * cellSideLength,
                                                     width: cellSideLength,
                                                     height: cellSideLength)
        
        self.invalidateIntrinsicContentSize()
    }
    
    func itemRequiresNumberLabel(_ item: String?, atRow row: Int, index: Int) -> Bool {
        return (row == 0 || index == 0) && item != "." ||
               (row > 0 && self.puzzleGrid[row - 1][index] == ".") && item != "." ||
               (index > 0 && self.puzzleGrid[row][index - 1] == ".") && item != "."
    }
    
    func createNumberTextLayer() -> CATextLayer {
        let layer = CATextLayer()
        layer.foregroundColor = UIColor.darkText.cgColor
        layer.contentsScale = self.window?.screen.scale ?? 1
        layer.actions = [
            "contents": NSNull()
        ]
        
        self.numberTextLayers.append(layer)
        self.puzzleContainerView.layer.addSublayer(layer)
        return layer
    }
    
    func syncCursorLayerCount() {
        while self.cursorIndicatorLayers.count != self.cursors.count {
            if self.cursorIndicatorLayers.count < self.cursors.count {
                let layer = CALayer()
                layer.backgroundColor = UIColor.systemPurple.cgColor
                self.puzzleContainerView.layer.insertSublayer(layer, at: 0)
                self.cursorIndicatorLayers.append(layer)
            } else {
                self.cursorIndicatorLayers.removeLast().removeFromSuperlayer()
            }
        }
    }
    
    func updateTextLayerCount(target: Int, font: UIFont) {
        while self.fillTextLayers.count != target {
            if self.fillTextLayers.count < target {
                let layer = CATextLayer()
                layer.font = font
                layer.fontSize = font.pointSize
                layer.foregroundColor = UIColor.black.cgColor
                layer.contentsScale = self.window?.screen.scale ?? 1
                layer.alignmentMode = .center
                layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                layer.actions = [
                    "contents": NSNull()
                ]
                
                self.puzzleContainerView.layer.addSublayer(layer)
                self.fillTextLayers.append(layer)
            } else {
                self.fillTextLayers.removeLast().removeFromSuperlayer()
            }
        }
    }
    
    func updateSeparatorCount(target: Int) {
        while self.separatorLayers.count != target {
            if self.separatorLayers.count < target {
                let layer = CALayer()
                layer.backgroundColor = UIColor.systemGray2.cgColor
                self.puzzleContainerView.layer.addSublayer(layer)
                self.separatorLayers.append(layer)
            } else {
                self.separatorLayers.removeLast().removeFromSuperlayer()
            }
        }
    }
    
    func advanceUserCursor() {
        let current = self.userCursor.coordinates
        func nextCandidate(after lastCandidate: CellCoordinates) -> CellCoordinates {
            switch self.userCursor.direction {
                case .across:
                    if lastCandidate.cell + 1 >= self.puzzleGrid[0].count {
                        return current
                    } else {
                        return CellCoordinates(row: lastCandidate.row, cell: lastCandidate.cell + 1)
                    }
                case .down:
                    if lastCandidate.row + 1 >= self.puzzleGrid.count {
                        return current
                    } else {
                        return CellCoordinates(row: lastCandidate.row + 1, cell: lastCandidate.cell)
                    }
            }
        }
        
        var candidate = nextCandidate(after: current)
        if candidate == current {
            return
        }
        
        while self.puzzleGrid[candidate.row][candidate.cell] == "." {
            candidate = nextCandidate(after: candidate)
            if candidate == current {
                return
            }
        }
        
        self.userCursor = UserCursor(coordinates: candidate, direction: self.userCursor.direction)
    }
    
    func retreatUserCursorIfNotAtNonemptyEdge() {
        let current = self.userCursor.coordinates
        func nextCandidate(after lastCandidate: CellCoordinates) -> CellCoordinates {
            switch self.userCursor.direction {
                case .across:
                    if lastCandidate.cell - 1 < 0 ||
                        lastCandidate.cell == self.solution[lastCandidate.row].count - 1 && self.solution[lastCandidate.row][lastCandidate.cell] != nil {
                        return current
                    } else {
                        return CellCoordinates(row: lastCandidate.row, cell: lastCandidate.cell - 1)
                    }
                case .down:
                    if lastCandidate.row - 1 < 0 ||
                        lastCandidate.row == self.solution.count - 1 && self.solution[lastCandidate.row][lastCandidate.cell]?.value != nil {
                        return current
                    } else {
                        return CellCoordinates(row: lastCandidate.row - 1, cell: lastCandidate.cell)
                    }
            }
        }
        
        
        var candidate = nextCandidate(after: current)
        
        while self.puzzleGrid[candidate.row][candidate.cell] == "." {
            candidate = nextCandidate(after: candidate)
            if candidate == current {
                return
            }
        }
        
        self.userCursor = UserCursor(coordinates: candidate, direction: self.userCursor.direction)
    }
    
    @objc func tapGestureRecognizerTriggered(_ tap: UITapGestureRecognizer) {
        let sideLength = Int(self.cellSideLength)

        let pointCoords = tap.location(in: self.scrollView)
        let cellCoords = CellCoordinates(row: Int(pointCoords.y) / sideLength,
                                         cell: Int(pointCoords.x) / sideLength)
        
        let item = self.puzzleGrid[cellCoords.row][cellCoords.cell]

        if item == nil || item == "." {
            return
        } else if cellCoords == self.userCursor.coordinates {
            self.userCursor = UserCursor(coordinates: cellCoords, direction: self.userCursor.direction.opposite)
        } else {
            self.userCursor = UserCursor(coordinates: cellCoords, direction: self.userCursor.direction)
        }
    }
    
}

extension PuzzleView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.puzzleContainerView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard let window = self.window else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fillTextLayers.forEach({ $0.contentsScale = window.screen.scale * scale })
        self.numberTextLayers.forEach({ $0.contentsScale = window.screen.scale * scale })
        CATransaction.commit()
    }
}

extension PuzzleView: UIKeyInput {
    
    var hasText: Bool {
        true
    }
    
    func insertText(_ text: String) {
        if text == " " {
            self.userCursor = UserCursor(coordinates: self.userCursor.coordinates, direction: self.userCursor.direction.opposite)
            return
        } else if text == "\n" {
            self.advanceUserCursor()
        } else {
            self.delegate?.puzzleView(self, didEnterText: text.uppercased(), atCoordinates: self.userCursor.coordinates)
            self.advanceUserCursor()
        }
    }
    
    func deleteBackward() {
        self.retreatUserCursorIfNotAtNonemptyEdge()
        self.delegate?.puzzleView(self, didEnterText: nil, atCoordinates: self.userCursor.coordinates)
    }
    
}
