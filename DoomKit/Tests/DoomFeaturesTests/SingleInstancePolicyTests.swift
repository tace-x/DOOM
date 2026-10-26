import Testing
import Foundation
@testable import DoomFeatures

struct SingleInstancePolicyTests {
    @Test("LIFE-14: Single instance policy identifies duplicate process")
    func duplicateProcessDetected() {
        let currentPID: pid_t = 1234
        let aloneList: [pid_t] = [1234]
        #expect(!SingleInstancePolicy.shouldTerminateDuplicate(currentPID: currentPID, existingPIDs: aloneList))

        let duplicateList: [pid_t] = [1234, 5678]
        #expect(SingleInstancePolicy.shouldTerminateDuplicate(currentPID: currentPID, existingPIDs: duplicateList))

        let anotherDuplicateList: [pid_t] = [9999]
        #expect(SingleInstancePolicy.shouldTerminateDuplicate(currentPID: currentPID, existingPIDs: anotherDuplicateList))
    }
}
