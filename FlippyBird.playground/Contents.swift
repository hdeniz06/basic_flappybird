#if canImport(PlaygroundSupport)
import PlaygroundSupport
#endif
import SpriteKit
import CoreGraphics
#if os(macOS)
import AppKit
#endif

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let bird: UInt32 = 1 << 0
    static let pipe: UInt32 = 1 << 1
    static let ground: UInt32 = 1 << 2
    static let scoreGate: UInt32 = 1 << 3
}

// MARK: - Level Configuration
struct LevelConfig {
    let name: String
    let pipeSpeed: CGFloat        // Negative (moving left)
    let spawnInterval: TimeInterval
    let gapHeight: CGFloat
    let pipeWidth: CGFloat
    let gravityDy: CGFloat
}

let levels: [LevelConfig] = [
    LevelConfig(name: "Seviye 1", pipeSpeed: -140, spawnInterval: 1.8, gapHeight: 180, pipeWidth: 60, gravityDy: -5.5),
    LevelConfig(name: "Seviye 2", pipeSpeed: -170, spawnInterval: 1.6, gapHeight: 165, pipeWidth: 60, gravityDy: -5.8),
    LevelConfig(name: "Seviye 3", pipeSpeed: -200, spawnInterval: 1.5, gapHeight: 150, pipeWidth: 58, gravityDy: -6.0),
    LevelConfig(name: "Seviye 4", pipeSpeed: -230, spawnInterval: 1.35, gapHeight: 135, pipeWidth: 56, gravityDy: -6.3),
    LevelConfig(name: "Seviye 5", pipeSpeed: -260, spawnInterval: 1.2, gapHeight: 120, pipeWidth: 54, gravityDy: -6.6)
]

// MARK: - Game Scene
final class GameScene: SKScene, SKPhysicsContactDelegate {
    private var bird: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!

    private var score: Int = 0 { didSet { scoreLabel.text = "Skor: \(score)" } }
    private var isGameOver: Bool = false
    private var isStarted: Bool = false

    private var spawnTimer: Timer?
    private var selectedLevelIndex: Int = 0
    private var currentLevel: LevelConfig { levels[selectedLevelIndex] }

    private let worldNode = SKNode()
    private let pipesNode = SKNode()

    private var floorY: CGFloat { 80 }

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.55, green: 0.78, blue: 0.98, alpha: 1.0)
        addChild(worldNode)
        worldNode.addChild(pipesNode)

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: currentLevel.gravityDy)

        setupGround()
        setupBird()
        setupUI()
        showLevelMenu()
    }

    // MARK: - Setup
    private func setupGround() {
        let ground = SKNode()
        ground.position = CGPoint(x: 0, y: floorY)
        ground.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: floorY), to: CGPoint(x: size.width, y: floorY))
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ground.physicsBody?.contactTestBitMask = PhysicsCategory.bird
        ground.physicsBody?.collisionBitMask = PhysicsCategory.bird
        ground.physicsBody?.isDynamic = false
        worldNode.addChild(ground)

        // Simple ground visual
        let groundShape = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: floorY))
        groundShape.fillColor = SKColor(red: 0.33, green: 0.77, blue: 0.39, alpha: 1.0)
        groundShape.strokeColor = .clear
        addChild(groundShape)
    }

    private func setupBird() {
        let birdSize = CGSize(width: 28, height: 28)
        bird = SKSpriteNode(color: SKColor(red: 1.0, green: 0.87, blue: 0.25, alpha: 1.0), size: birdSize)
        bird.position = CGPoint(x: size.width * 0.35, y: size.height * 0.6)
        bird.zPosition = 10
        bird.physicsBody = SKPhysicsBody(circleOfRadius: birdSize.width * 0.5)
        bird.physicsBody?.allowsRotation = false
        bird.physicsBody?.categoryBitMask = PhysicsCategory.bird
        bird.physicsBody?.contactTestBitMask = PhysicsCategory.pipe | PhysicsCategory.ground | PhysicsCategory.scoreGate
        bird.physicsBody?.collisionBitMask = PhysicsCategory.pipe | PhysicsCategory.ground
        bird.physicsBody?.isDynamic = true
        bird.physicsBody?.affectedByGravity = false
        worldNode.addChild(bird)
    }

    private func setupUI() {
        scoreLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        scoreLabel.fontSize = 28
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 16)
        scoreLabel.fontColor = .white
        score = 0
        addChild(scoreLabel)

        levelLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        levelLabel.fontSize = 18
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .top
        levelLabel.position = CGPoint(x: 16, y: size.height - 20)
        levelLabel.fontColor = .white
        addChild(levelLabel)

        hintLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        hintLabel.fontSize = 18
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        hintLabel.fontColor = SKColor(white: 1, alpha: 0.9)
        addChild(hintLabel)
    }

    private func showLevelMenu() {
        isGameOver = false
        isStarted = false
        pipesNode.removeAllChildren()
        bird.position = CGPoint(x: size.width * 0.35, y: size.height * 0.6)
        bird.zRotation = 0
        bird.physicsBody?.affectedByGravity = false
        score = 0

        levelLabel.text = "Seviye: -"
        hintLabel.text = "Seviye seçin: 1  2  3  4  5\nBaşlamak için numaraya dokunun / tıklayın"

        // Create tappable level buttons
        let buttonGap: CGFloat = 64
        for (index, _) in levels.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: 50, height: 50), cornerRadius: 8)
            button.fillColor = SKColor(white: 1, alpha: 0.2)
            button.strokeColor = SKColor(white: 1, alpha: 0.9)
            button.position = CGPoint(x: (size.width / 2) - (buttonGap * 2) + CGFloat(index) * buttonGap, y: size.height * 0.45)
            button.name = "level_\(index)"

            let label = SKLabelNode(fontNamed: "Avenir-Heavy")
            label.text = "\(index + 1)"
            label.fontSize = 22
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.fontColor = .white
            label.name = "level_\(index)"
            button.addChild(label)
            addChild(button)
        }
    }

    private func startGame(level index: Int) {
        // Clear level buttons
        children.filter { $0.name?.starts(with: "level_") == true }.forEach { $0.removeFromParent() }

        selectedLevelIndex = index
        physicsWorld.gravity = CGVector(dx: 0, dy: currentLevel.gravityDy)
        levelLabel.text = "Seviye: \(currentLevel.name)"
        hintLabel.text = "Uçmak için dokun / tıkla"

        isStarted = true
        isGameOver = false
        score = 0
        bird.position = CGPoint(x: size.width * 0.35, y: size.height * 0.6)
        bird.physicsBody?.velocity = .zero
        bird.physicsBody?.affectedByGravity = true

        startSpawningPipes()
    }

    private func startSpawningPipes() {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: currentLevel.spawnInterval, repeats: true) { [weak self] _ in
            self?.spawnPipePair()
        }
    }

    private func stopSpawningPipes() {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    // MARK: - Pipes
    private func spawnPipePair() {
        let centerY = CGFloat.random(in: floorY + 120 ... size.height - 120)
        let gap = currentLevel.gapHeight
        let pipeWidth = currentLevel.pipeWidth

        let topHeight = max(40, size.height - centerY - gap / 2)
        let bottomHeight = max(40, centerY - gap / 2 - floorY)

        let topPipe = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: topHeight))
        topPipe.fillColor = SKColor(red: 0.32, green: 0.80, blue: 0.36, alpha: 1)
        topPipe.strokeColor = .clear
        topPipe.position = CGPoint(x: size.width + pipeWidth, y: size.height - topHeight / 2)
        topPipe.zPosition = 5
        topPipe.name = "pipe"
        topPipe.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: topHeight))
        topPipe.physicsBody?.isDynamic = false
        topPipe.physicsBody?.categoryBitMask = PhysicsCategory.pipe
        topPipe.physicsBody?.contactTestBitMask = PhysicsCategory.bird
        pipesNode.addChild(topPipe)

        let bottomPipe = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: bottomHeight))
        bottomPipe.fillColor = SKColor(red: 0.32, green: 0.80, blue: 0.36, alpha: 1)
        bottomPipe.strokeColor = .clear
        bottomPipe.position = CGPoint(x: size.width + pipeWidth, y: floorY + bottomHeight / 2)
        bottomPipe.zPosition = 5
        bottomPipe.name = "pipe"
        bottomPipe.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: bottomHeight))
        bottomPipe.physicsBody?.isDynamic = false
        bottomPipe.physicsBody?.categoryBitMask = PhysicsCategory.pipe
        bottomPipe.physicsBody?.contactTestBitMask = PhysicsCategory.bird
        pipesNode.addChild(bottomPipe)

        // Score gate (invisible)
        let gate = SKNode()
        gate.position = CGPoint(x: size.width + pipeWidth + (pipeWidth / 2), y: centerY)
        gate.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: gap))
        gate.physicsBody?.isDynamic = false
        gate.physicsBody?.categoryBitMask = PhysicsCategory.scoreGate
        gate.physicsBody?.contactTestBitMask = PhysicsCategory.bird
        gate.physicsBody?.collisionBitMask = PhysicsCategory.none
        pipesNode.addChild(gate)

        // Movement
        let totalDistance = size.width + pipeWidth * 2
        let duration = TimeInterval(abs(totalDistance / currentLevel.pipeSpeed))
        let move = SKAction.moveBy(x: currentLevel.pipeSpeed * duration, y: 0, duration: duration)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([move, remove])
        topPipe.run(sequence)
        bottomPipe.run(sequence)
        gate.run(sequence)
    }

    // MARK: - Touches
#if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleTap(at: location)
    }
#endif
#if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location)
    }
#endif

    private func handleTap(at location: CGPoint) {
        if !isStarted {
            if let name = nodes(at: location).first(where: { $0.name?.starts(with: "level_") == true })?.name,
               let indexString = name.split(separator: "_").last,
               let index = Int(indexString), index < levels.count {
                startGame(level: index)
                return
            }
            return
        }
        if isGameOver { restart(); return }
        flap()
    }

    private func flap() {
        guard isStarted && !isGameOver else { return }
        bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 12))
        let tiltUp = SKAction.rotate(toAngle: 0.35, duration: 0.1, shortestUnitArc: true)
        let tiltDown = SKAction.rotate(toAngle: -0.6, duration: 0.6)
        bird.run(SKAction.sequence([tiltUp, tiltDown]))
    }

    // MARK: - Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        if (a == PhysicsCategory.scoreGate && b == PhysicsCategory.bird) ||
            (b == PhysicsCategory.scoreGate && a == PhysicsCategory.bird) {
            score += 1
            (a == PhysicsCategory.scoreGate ? contact.bodyA.node : contact.bodyB.node)?.removeFromParent()
            return
        }

        if (a == PhysicsCategory.pipe && b == PhysicsCategory.bird) ||
            (b == PhysicsCategory.pipe && a == PhysicsCategory.bird) ||
            (a == PhysicsCategory.ground && b == PhysicsCategory.bird) ||
            (b == PhysicsCategory.ground && a == PhysicsCategory.bird) {
            gameOver()
        }
    }

    private func gameOver() {
        guard !isGameOver else { return }
        isGameOver = true
        stopSpawningPipes()
        hintLabel.text = "Oyun Bitti!\nTekrar oynamak için dokun / tıkla"
        pipesNode.children.forEach { $0.removeAllActions() }
    }

    private func restart() {
        stopSpawningPipes()
        pipesNode.removeAllChildren()
        showLevelMenu()
    }
}

// MARK: - Present Scene in Playground
let sceneSize = CGSize(width: 400, height: 700)
let scene = GameScene(size: sceneSize)
scene.scaleMode = .aspectFit

let skView = SKView(frame: CGRect(origin: .zero, size: sceneSize))
skView.ignoresSiblingOrder = true
skView.showsFPS = true
skView.showsNodeCount = true
skView.presentScene(scene)

#if canImport(PlaygroundSupport)
PlaygroundPage.current.liveView = skView
PlaygroundPage.current.needsIndefiniteExecution = true
#endif 