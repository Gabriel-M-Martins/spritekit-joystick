//
//  GameScene.swift
//  demoGame
//
//  Created by Gabriel Medeiros Martins on 19/09/23.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    var entities = [GKEntity]()
    
    private var lastUpdateTime : TimeInterval = 0
    private var tilemap: SKTileMapNode = SKTileMapNode()
    
    private lazy var grassTile: SKTileGroup? = tilemap.tileSet.tileGroups.first(where: { $0.name == "Grass"})
    private lazy var sandTile: SKTileGroup? = tilemap.tileSet.tileGroups.first(where: { $0.name == "Sand"})
    private lazy var cobblestoneTile: SKTileGroup? = tilemap.tileSet.tileGroups.first(where: { $0.name == "Cobblestone"})
    private lazy var waterTile: SKTileGroup? = tilemap.tileSet.tileGroups.first(where: { $0.name == "Water"})
    
    private var player: SKSpriteNode = SKSpriteNode()
    private var playerMoveSpeed: CGFloat = 10
    
    private var outerJoystick: SKShapeNode = SKShapeNode()
    private var innerJoystick: SKShapeNode = SKShapeNode()
    
    private var currentTouch: UITouch?
    
    private var joystickMoveTime: Double = 0.08
    private var joystickSize: CGFloat = 120
    private var joystickScaleFactor: CGFloat = 1.2
    private var joystickScaleTime: CGFloat = 0.08
    private var isJoystickHidden: Bool = false
    
    private var cameraScale: CGFloat = 1
    
    // MARK: - SceneDidLoad
    override func sceneDidLoad() {
        self.lastUpdateTime = 0
        
        setupPlayer()
        
        setupMap()
        
        setupJoystick()
    
        setupCamera()
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        // Initialize _lastUpdateTime if it has not already been
        if (self.lastUpdateTime == 0) {
            self.lastUpdateTime = currentTime
        }
        
        // Calculate time since last update
        _ = currentTime - self.lastUpdateTime
        
        if innerJoystick.position != .zero {
            let newPos = CGPoint(x: self.player.position.x + innerJoystick.position.x, y: self.player.position.y + innerJoystick.position.y)
            let duration = 1/playerMoveSpeed
            
            let playerActions = SKAction.group([
                .move(to: newPos, duration: duration),
                .run { [weak self] in
                    if let self = self {
                        self.player.zRotation = atan2(self.innerJoystick.position.y, self.innerJoystick.position.x)
                    }
                }
            ])
            self.player.run(playerActions)
            
            self.camera?.run(.move(to: newPos, duration: duration))
            
            self.outerJoystick.run(.move(to: CGPoint(x: self.outerJoystick.position.x + innerJoystick.position.x, y: self.outerJoystick.position.y + innerJoystick.position.y), duration: duration))
        }
        
        self.lastUpdateTime = currentTime
    }
    
    
    @objc func rotated() {
        if UIDevice.current.orientation.isLandscape {
            setCameraScale(to: 2)
        } else {
            setCameraScale(to: 1)
        }
    }
    
    
    // MARK: - Touches
    func clearTouch() {
        if self.currentTouch != nil {
            self.currentTouch = nil
        }
        
        if !isJoystickHidden {
            toggleJoystick()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.currentTouch != nil { return }
        if let touch = touches.first {
            toggleJoystick()
            
            outerJoystick.position = touch.location(in: scene!)
            
            innerJoystick.run(.move(to: touch.location(in: outerJoystick), duration: joystickMoveTime))
            innerJoystick.run(.scale(to: joystickScaleFactor, duration: joystickScaleTime))
            self.currentTouch = touch
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == self.currentTouch {
                var position: CGPoint
                
                let pointInScene = touch.location(in: scene!)
                if outerJoystick.contains(pointInScene) {
                    position = touch.location(in: outerJoystick)
                } else {
                    let limitedPosPreNormalization = CGPoint(x: pointInScene.x - outerJoystick.position.x, y: pointInScene.y - outerJoystick.position.y)
                    let size = sqrt(pow(limitedPosPreNormalization.x, 2) + pow(limitedPosPreNormalization.y, 2))
                    
                    let limitedPosNormalized = CGPoint(x: (limitedPosPreNormalization.x/size) * joystickSize, y: (limitedPosPreNormalization.y/size) * joystickSize)
                    
                    position = limitedPosNormalized
                }
                
                innerJoystick.run(.move(to: position, duration: joystickMoveTime))
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = self.currentTouch {
            if touches.contains(touch) {
                self.currentTouch = nil

                innerJoystick.run(.move(to: .zero, duration: joystickMoveTime))
                innerJoystick.run(.scale(to: 1, duration: joystickScaleTime))

                toggleJoystick()
            }
        }
    }
    
    // MARK: - Camera
    private func setupCamera() {
        let camera = SKCameraNode()
        camera.setScale(1)
        
        self.camera = camera
        addChild(camera)
    }
    
    private func setCameraScale(to scale: CGFloat) {
        camera?.run(.scale(to: scale, duration: joystickScaleTime))
    }
    
    // MARK: - Player
    private func setupPlayer() {
        let size = 50
        player = SKSpriteNode(color: .purple, size: CGSize(width: size, height: size))
        player.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        player.zPosition = 2
        self.addChild(player)
    }
    
    // MARK: - Map
    private func setupMap() {
        let tileset = SKTileSet(named: "Sample Grid Tile Set")!
        let tilesize = CGSize(width: 128, height: 128)
        let rows = 50, cols = 50
        
        let noiseMap = createNoiseMap(rows: rows, cols: cols)
        
        self.tilemap = SKTileMapNode(tileSet: tileset, columns: cols, rows: rows, tileSize: tilesize)
        self.tilemap.enableAutomapping = true

        for column in 0..<cols {
            for row in 0..<rows {
                let val = noiseMap.value(at: vector2(Int32(row),Int32(column)))
                switch val {
                case -1..<(-0.5):
                    if let tile = sandTile {
                        self.tilemap.setTileGroup(tile, forColumn: column, row: row)
                    }
                case -0.5..<0:
                    if let tile = cobblestoneTile {
                        self.tilemap.setTileGroup(tile, forColumn: column, row: row)
                    }
                default:
                    if let tile = grassTile {
                        self.tilemap.setTileGroup(tile, forColumn: column, row: row)
                    }
                }
            }
        }
        
        let backgroundMap = SKTileMapNode(tileSet: tileset, columns: cols, rows: rows, tileSize: tilesize)
        backgroundMap.fill(with: waterTile)
        backgroundMap.zPosition = -1
        
        self.tilemap.zRotation = .pi
 
        self.addChild(backgroundMap)
        self.addChild(self.tilemap)
    }
    
    // MARK: - Joystick
    private func setupJoystick() {
        outerJoystick = SKShapeNode(circleOfRadius: joystickSize)
        
        outerJoystick.fillColor = .white.withAlphaComponent(0.4)
        outerJoystick.zPosition = 10
        
        innerJoystick = SKShapeNode(circleOfRadius: joystickSize/3)
        
        innerJoystick.fillColor = .black
        innerJoystick.strokeColor = .darkGray
        innerJoystick.lineWidth = 2
        innerJoystick.zPosition = 11
        
        outerJoystick.addChild(innerJoystick)
        
        self.addChild(outerJoystick)
        
        let y = -1 * (self.size.height/2) + (joystickSize * 1.5)
        outerJoystick.position = CGPoint(x: outerJoystick.position.x, y: y)
        
        toggleJoystick()
    }
    
    private func toggleJoystick() {
        let action: SKAction
        if isJoystickHidden {
            action = .sequence([
                .unhide(),
                .scale(to: 1, duration: joystickScaleTime)
            ])
        } else {
            action = .sequence([
                .scale(to: 0.01, duration: joystickScaleTime),
                .hide()
            ])
        }
        
        outerJoystick.run(action)
        isJoystickHidden.toggle()
    }
}


func createNoiseMap(rows: Int, cols: Int) -> GKNoiseMap {
    //Get our noise source, this can be customized further
    let source = GKPerlinNoiseSource() //Initalize our GKNoise object with our source
    source.seed = Int32.random(in: 0..<100000)
    let noise = GKNoise.init(source) // Create our map
    
    // sampleCount = to the number of tiles in the grid (row, col)
    let map = GKNoiseMap.init(noise, size: vector2(1.0, 1.0), origin: vector2(0, 0), sampleCount: vector2(Int32(rows), Int32(cols)), seamless: true)
    
    return map
}
