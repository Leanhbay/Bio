import UIKit

class ViewController: UIViewController {
    private var tableView = PoolTableView()
    private var overlayWindow: UIWindow?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .darkGray
        setupTableView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupFloatingOverlay()
    }
    
    private func setupTableView() {
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
    }
    
    private func setupFloatingOverlay() {
        guard let windowScene = view.window?.windowScene else { return }
        
        overlayWindow = PassThroughWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = .statusBar + 1
        overlayWindow?.backgroundColor = .clear
        
        let overlayVC = UIViewController()
        overlayVC.view.backgroundColor = .clear
        
        let panelView = FloatingPanelView(frame: CGRect(x: 20, y: 100, width: 200, height: 50))
        overlayVC.view.addSubview(panelView)
        
        panelView.onToggle = { [weak self] isOn in
            self?.tableView.showGuideline = isOn
            self?.tableView.setNeedsDisplay()
        }
        
        overlayWindow?.rootViewController = overlayVC
        overlayWindow?.isHidden = false
    }
}

class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == rootViewController?.view { return nil }
        return hitView
    }
}

class FloatingPanelView: UIView {
    var onToggle: ((Bool) -> Void)?
    private var isOn: Bool = true
    private var switchView = UISwitch()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        layer.cornerRadius = 15
        clipsToBounds = true
        
        let label = UILabel(frame: CGRect(x: 10, y: 15, width: 100, height: 20))
        label.text = "Guideline"
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 14)
        addSubview(label)
        
        switchView.frame = CGRect(x: 130, y: 10, width: 50, height: 30)
        switchView.isOn = true
        switchView.onTintColor = .systemGreen
        switchView.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        addSubview(switchView)
    }
    
    @objc private func toggleChanged() {
        isOn = switchView.isOn
        onToggle?(isOn)
    }
    
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
    }
}

class PoolTableView: UIView {
    let tableRect = CGRect(x: 50, y: 100, width: 300, height: 150)
    let ballRadius: CGFloat = 10
    let cueBallPos = CGPoint(x: 130, y: 175)
    let targetBallPos = CGPoint(x: 250, y: 160)
    
    var aimAngle: CGFloat = 0
    var showGuideline: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func touchesMoved(_ touches: Set, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let dx = location.x - cueBallPos.x
        let dy = location.y - cueBallPos.y
        aimAngle = atan2(dy, dx)
        self.setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect: rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        drawTable(context: context)
        drawBalls(context: context)
        
        if showGuideline {
            calculateAndDrawGuideline(context: context)
        } else {
            drawShortCue(context: context)
        }
    }
    
    private func drawTable(context: CGContext) {
        context.setFillColor(brown: 139, green: 90, blue: 43, alpha: 1)
        context.fill(tableRect.insetBy(dx: -20, dy: -20))
        context.setFillColor(brown: 39, green: 119, blue: 60, alpha: 1)
        context.fill(tableRect)
    }
    
    private func drawBalls(context: CGContext) {
        context.setFillColor(UIColor.white.cgColor)
        context.fillCircle(center: cueBallPos, radius: ballRadius)
        context.setFillColor(UIColor.red.cgColor)
        context.fillCircle(center: targetBallPos, radius: ballRadius)
    }
    
    private func drawShortCue(context: CGContext) {
        let endX = cueBallPos.x + cos(aimAngle) * 50
        let endY = cueBallPos.y + sin(aimAngle) * 50
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1)
        context.move(to: cueBallPos)
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.strokePath()
    }
    
    private func calculateAndDrawGuideline(context: CGContext) {
        let dirX = cos(aimAngle)
        let dirY = sin(aimAngle)
        
        let dx = cueBallPos.x - targetBallPos.x
        let dy = cueBallPos.y - targetBallPos.y
        let a = dirX * dirX + dirY * dirY
        let b = 2 * (dx * dirX + dy * dirY)
        let c = dx * dx + dy * dy - (ballRadius * 2) * (ballRadius * 2)
        
        let discriminant = b * b - 4 * a * c
        
        if discriminant >= 0 {
            let t = (-b - sqrt(discriminant)) / (2 * a)
            if t > 0 {
                let ghostBallX = cueBallPos.x + dirX * t
                let ghostBallY = cueBallPos.y + dirY * t
                let ghostBallPos = CGPoint(x: ghostBallX, y: ghostBallY)
                
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                context.setLineWidth(1.5)
                context.setLineDash(phase: 0, lengths: [5, 5])
                context.move(to: cueBallPos)
                context.addLine(to: ghostBallPos)
                context.strokePath()
                context.setLineDash(phase: 0, lengths: [])
                
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
                context.setLineWidth(1)
                context.strokeCircle(center: ghostBallPos, radius: ballRadius)
                
                let targetDirX = targetBallPos.x - ghostBallX
                let targetDirY = targetBallPos.y - ghostBallY
                let targetLength = sqrt(targetDirX * targetDirX + targetDirY * targetDirY)
                
                if targetLength > 0 {
                    let normTargetX = targetDirX / targetLength
                    let normTargetY = targetDirY / targetLength
                    
                    context.setStrokeColor(UIColor.yellow.cgColor)
                    context.setLineWidth(2)
                    context.move(to: targetBallPos)
                    
                    let predictionLength: CGFloat = 150
                    let endTargetX = targetBallPos.x + normTargetX * predictionLength
                    let endTargetY = targetBallPos.y + normTargetY * predictionLength
                    
                    if let wallHitPoint = checkWallIntersection(start: targetBallPos, dirX: normTargetX, dirY: normTargetY) {
                        context.addLine(to: wallHitPoint)
                        context.strokePath()
                        drawBankShot(context: context, hitPoint: wallHitPoint, inDirX: normTargetX, inDirY: normTargetY)
                    } else {
                        context.addLine(to: CGPoint(x: endTargetX, y: endTargetY))
                        context.strokePath()
                    }
                }
            }
        }
    }
    
    private func checkWallIntersection(start: CGPoint, dirX: CGFloat, dirY: CGFloat) -> CGPoint? {
        var minT: CGFloat = .greatestFiniteMagnitude
        var hitPoint: CGPoint?
        
        if dirX < 0 {
            let t = (tableRect.minX - start.x) / dirX
            let y = start.y + t * dirY
            if t > 0 && y >= tableRect.minY && y <= tableRect.maxY && t < minT {
                minT = t; hitPoint = CGPoint(x: tableRect.minX, y: y)
            }
        }
        if dirX > 0 {
            let t = (tableRect.maxX - start.x) / dirX
            let y = start.y + t * dirY
            if t > 0 && y >= tableRect.minY && y <= tableRect.maxY && t < minT {
                minT = t; hitPoint = CGPoint(x: tableRect.maxX, y: y)
            }
        }
        if dirY < 0 {
            let t = (tableRect.minY - start.y) / dirY
            let x = start.x + t * dirX
            if t > 0 && x >= tableRect.minX && x <= tableRect.maxX && t < minT {
                minT = t; hitPoint = CGPoint(x: x, y: tableRect.minY)
            }
        }
        if dirY > 0 {
            let t = (tableRect.maxY - start.y) / dirY
            let x = start.x + t * dirX
            if t > 0 && x >= tableRect.minX && x <= tableRect.maxX && t < minT {
                minT = t; hitPoint = CGPoint(x: x, y: tableRect.maxY)
            }
        }
        return hitPoint
    }
    
    private func drawBankShot(context: CGContext, hitPoint: CGPoint, inDirX: CGFloat, inDirY: CGFloat) {
        var normX: CGFloat = 0
        var normY: CGFloat = 0
        
        if hitPoint.x == tableRect.minX || hitPoint.x == tableRect.maxX { normX = 1 }
        if hitPoint.y == tableRect.minY || hitPoint.y == tableRect.maxY { normY = 1 }
        
        let dot = inDirX * normX + inDirY * normY
        let outDirX = inDirX - 2 * dot * normX
        let outDirY = inDirY - 2 * dot * normY
        
        context.setStrokeColor(UIColor.orange.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [8, 4])
        context.move(to: hitPoint)
        
        let bankLength: CGFloat = 100
        context.addLine(to: CGPoint(x: hitPoint.x + outDirX * bankLength, y: hitPoint.y + outDirY * bankLength))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }
}

extension CGContext {
    func fillCircle(center: CGPoint, radius: CGFloat) {
        fill(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    func strokeCircle(center: CGPoint, radius: CGFloat) {
        strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    func setFillColor(brown: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        setFillColor(UIColor(red: brown/255, green: green/255, blue: blue/255, alpha: alpha).cgColor)
    }
}
