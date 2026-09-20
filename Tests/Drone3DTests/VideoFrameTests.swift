import XCTest
@testable import Drone3DApp

final class VideoFrameTests: XCTestCase {
    func testHigherLimitsSelectMoreOrderedFrames() {
        let scores = (0..<1440).map {
            VideoFrameExtractor.ScoredFrame(time: Double($0) / 24, quality: Double($0 % 7))
        }
        for count in [240, 480, 720] {
            let times = VideoFrameExtractor.selectSharpestTimes(duration: 60, count: count, scores: scores)
            XCTAssertEqual(times.count, count)
            XCTAssertEqual(times, times.sorted())
            XCTAssertEqual(Set(times).count, count)
        }
    }

    func testSparseVideoDoesNotInventFrames() {
        let scores = [VideoFrameExtractor.ScoredFrame(time: 0, quality: 1),
                      VideoFrameExtractor.ScoredFrame(time: 0.01, quality: 10),
                      VideoFrameExtractor.ScoredFrame(time: 3, quality: 5)]
        XCTAssertEqual(VideoFrameExtractor.selectSharpestTimes(duration: 10, count: 240, scores: scores), [0.01, 3])
    }
}
