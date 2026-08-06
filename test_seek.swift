import Foundation
import AVFoundation

let url = URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!
let player = AVQueuePlayer(url: url)
player.play()
RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
player.seek(to: CMTime(seconds: 30, preferredTimescale: 600)) { finished in
    print("Seek finished: \(finished)")
}
RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
print("Current time: \(player.currentTime().seconds)")
